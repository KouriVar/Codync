import AVFoundation
import CodyncKit
import Foundation
import Speech

/// What one recording reports while it runs. No display strings: the caller localizes.
public enum SpeechEvent: Sendable {
    /// The words heard so far, rewritten as the recognizer firms them up.
    case partial(String)
    /// The microphone's loudness, 0…1.
    case level(Float)
    /// It stopped early; nothing more comes.
    case failed(SpeechFailureReason)
}

public enum SpeechFailureReason: Sendable, Equatable {
    case permissionDenied
    case unavailable
    case microphone
}

public enum SpeechPermission: Sendable, Equatable {
    case granted
    case denied
    case unavailable
}

/// Speech to words. The home capsule talks to this protocol only, so a cloud service (mimo, say)
/// replaces the on-device recognizer by swapping the implementation, not the capsule.
@MainActor
public protocol SpeechTranscriber: AnyObject {
    /// The language to hear, applied to the next `start`.
    var locale: Locale { get set }
    /// Whether anything is being heard right now (paused counts as stopped).
    var isRecording: Bool { get }
    func permission() async -> SpeechPermission
    /// Opens the microphone and reports as it goes. Nothing ends it on its own: it records until
    /// `pause`, `finish` or `cancel`. Throws when the microphone can't be used.
    func start(_ report: @escaping @MainActor @Sendable (SpeechEvent) -> Void) throws
    /// Stops hearing and keeps the words so far, so `resume` can carry on.
    func pause()
    /// Hears again after `pause`.
    @discardableResult func resume() -> Bool
    /// Ends the recording and gives the final words (what was heard so far if the recognizer stalls).
    func finish() async -> String
    /// Drops everything at once.
    func cancel()
}

/// The phone's own recognizer (SFSpeechRecognizer), on device when the phone supports it.
///
/// One recognizer task lives for about a minute, so a long recording is a relay of tasks. The next
/// one starts *before* the last is closed and both hear the microphone for a beat, so no audio falls
/// into the seam; the closing task's last words are then folded in, with the words repeated across
/// the seam dropped. To the user it is one continuous recording.
@MainActor
public final class OnDeviceSpeechTranscriber: SpeechTranscriber {
    /// A task is replaced this long after it starts, well inside the recognizer's own minute.
    private static let taskLifetime: TimeInterval = 44
    /// How long the old and the new task both hear the microphone.
    private static let overlap: Duration = .milliseconds(300)

    public var locale: Locale
    public private(set) var isRecording = false

    /// Built on the first recording: an AVAudioEngine is heavy enough to be felt when the home draws.
    private lazy var engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private let sink = BufferSink()
    private var report: (@MainActor @Sendable (SpeechEvent) -> Void)?
    /// Bumped by every start and cancel, so late results from an older recording are dropped.
    private var generation = 0
    /// A tap is installed on the input node; only then may it be taken off.
    private var tapped = false
    /// The tasks hearing the microphone, oldest first; a closing one is only waiting for its last words.
    private var hearings: [Hearing] = []
    /// Words of tasks that are wholly finished, oldest first.
    private var committed: [String] = []
    private var nextID = 1
    /// When the newest task started: a task is replaced a little before the recognizer's own limit.
    private var newestTaskAt = Date.now
    private var rotation: Task<Void, Never>?
    /// `finish` waits here for the recognizers' last words, unless they take too long.
    private var settling: CheckedContinuation<Void, Never>?

    private struct Hearing {
        let id: Int
        let request: SFSpeechAudioBufferRecognitionRequest
        var task: SFSpeechRecognitionTask?
        var text = ""
        /// Its audio is closed; it only has to hand back its last words.
        var closing = false
    }

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
    }

    /// Everything heard so far, the seams between tasks deduplicated.
    private var words: String {
        Self.join(committed + hearings.map(\.text))
    }

    // MARK: permission

    public func permission() async -> SpeechPermission {
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else { return .denied }
        guard await Self.authorized() else { return .denied }
        guard SFSpeechRecognizer(locale: locale) != nil else { return .unavailable }
        return .granted
    }

    private nonisolated static func authorized() async -> Bool {
        await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0 == .authorized) }
        }
    }

    // MARK: recording

    public func start(_ report: @escaping @MainActor @Sendable (SpeechEvent) -> Void) throws {
        cancel()
        generation += 1
        self.report = report
        committed = []
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(), recognizer.isAvailable else {
            self.report = nil
            throw SpeechUnavailable()
        }
        self.recognizer = recognizer
        startTask()
        guard openMic() else {
            cancel()
            throw SpeechUnavailable()
        }
        isRecording = true
        watchRotation(generation: generation)
    }

    public func pause() {
        guard isRecording else { return }
        isRecording = false
        closeMic()
        report?(.level(0))
    }

    @discardableResult
    public func resume() -> Bool {
        guard !isRecording, !hearings.isEmpty else { return false }
        guard openMic() else {
            cancel()
            report?(.failed(.microphone))
            return false
        }
        isRecording = true
        newestTaskAt = .now
        // Every task may have run out of its minute while we were paused.
        if !hearings.contains(where: { !$0.closing }) { startTask() }
        return true
    }

    public func finish() async -> String {
        guard !hearings.isEmpty else {
            let said = words
            release()
            return said
        }
        isRecording = false
        closeMic()
        for hearing in hearings where !hearing.closing { close(id: hearing.id) }
        // The recognizers' last words arrive a moment after the audio ends.
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            settling = done
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(1200))
                self?.settle()
            }
        }
        let said = words
        release()
        return said
    }

    public func cancel() {
        generation += 1
        release()
        settle()
    }

    // MARK: the relay of tasks

    /// Starts hearing with a fresh request: the first task, and every replacement after it.
    private func startTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        // On device when the phone can: nothing said leaves the phone.
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        let id = nextID
        nextID += 1
        hearings.append(Hearing(id: id, request: request))
        refreshSink()
        newestTaskAt = .now
        let generation = generation
        let task = recognizer.recognitionTask(with: request,
                                             resultHandler: Self.results(id: id, generation: generation, into: self))
        if let index = hearings.firstIndex(where: { $0.id == id }) { hearings[index].task = task }
    }

    /// The next task hears the microphone before the last one stops: whichever buffer a seam falls
    /// between, one of them has it. The old one is closed a beat later and its words folded in.
    private func rotate() {
        guard isRecording, let old = hearings.first(where: { !$0.closing }) else { return }
        startTask()
        let id = old.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.overlap)
            self?.close(id: id)
        }
    }

    private func close(id: Int) {
        guard let index = hearings.firstIndex(where: { $0.id == id }), !hearings[index].closing else { return }
        hearings[index].closing = true
        hearings[index].request.endAudio()
        refreshSink()
    }

    /// Whatever is still hearing goes to the microphone; a closing task gets nothing more.
    private func refreshSink() {
        sink.hold(hearings.filter { !$0.closing }.map(\.request))
    }

    private func watchRotation(generation: Int) {
        rotation?.cancel()
        rotation = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.generation == generation, self.isRecording else { return }
                if Date.now.timeIntervalSince(self.newestTaskAt) > Self.taskLifetime { self.rotate() }
            }
        }
    }

    // MARK: what the recognizers say

    /// The recognizer calls this on its own queue, so it's built outside the main actor and hops
    /// back before touching anything (an inferred main-actor closure called off the main thread
    /// traps in `_dispatch_assert_queue_fail`).
    private nonisolated static func results(id: Int, generation: Int, into transcriber: OnDeviceSpeechTranscriber)
        -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard transcriber.generation == generation else { return }
                if let text { transcriber.recognized(id: id, text: text) }
                if final || failed { transcriber.taskEnded(id: id) }
            }
        }
    }

    private func recognized(id: Int, text: String) {
        guard let index = hearings.firstIndex(where: { $0.id == id }) else { return }
        hearings[index].text = text
        report?(.partial(words))
    }

    /// A task is done: its words move into the running text and it leaves the microphone alone. With
    /// nothing left hearing but a live recording — a task that gave up early — a new one starts.
    private func taskEnded(id: Int) {
        guard let index = hearings.firstIndex(where: { $0.id == id }) else { return }
        let text = hearings[index].text
        hearings.remove(at: index)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { committed.append(text) }
        report?(.partial(words))
        if hearings.isEmpty {
            if isRecording {
                startTask()
            } else {
                settle()
            }
        }
    }

    /// Wakes `finish` once; anything the recognizers say afterwards is dropped.
    private func settle() {
        settling?.resume()
        settling = nil
    }

    private func release() {
        rotation?.cancel()
        rotation = nil
        for hearing in hearings {
            hearing.task?.cancel()
            hearing.request.endAudio()
        }
        hearings = []
        committed = []
        sink.hold([])
        recognizer = nil
        closeMic()
        report?(.level(0))
        report = nil
        isRecording = false
    }

    // MARK: the seam

    /// The tasks end and start mid-sentence, so their words overlap: drop the longest tail of the
    /// text so far that repeats the head of the next one.
    private static func join(_ parts: [String]) -> String {
        parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce("") { head, next in
                guard !head.isEmpty else { return next }
                let overlap = selfOverlap(head, next)
                let rest = String(next.dropFirst(overlap))
                guard !rest.isEmpty else { return head }
                // English words need the space; Chinese does not.
                let needsSpace = head.last?.isASCII == true && rest.first?.isASCII == true
                return head + (needsSpace ? " " : "") + rest
            }
    }

    /// How many characters at the end of `head` are also at the start of `next`.
    private static func selfOverlap(_ head: String, _ next: String) -> Int {
        let limit = min(head.count, next.count, 60)
        guard limit >= 2 else { return 0 }
        for length in stride(from: limit, through: 2, by: -1) where head.hasSuffix(String(next.prefix(length))) {
            return length
        }
        return 0
    }

    // MARK: the microphone

    private func openMic() -> Bool {
        let audio = AVAudioSession.sharedInstance()
        do {
            // The session has to be in a record category and active before the tap goes on.
            try audio.setCategory(.playAndRecord, mode: .default,
                                  options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try audio.setActive(true)
            let input = engine.inputNode
            // The buffer's own format: a tap in any other format is refused or raises.
            let format = try MicTap.format(of: input)
            input.removeTap(onBus: 0)
            let sink = self.sink
            input.installTap(onBus: 0, bufferSize: 2048, format: format,
                             block: Self.tap(sink) { [weak self] level in
                                 Task { @MainActor in self?.heard(level: level) }
                             })
            tapped = true
            engine.prepare()
            try engine.start()
            return true
        } catch {
            if tapped {
                engine.inputNode.removeTap(onBus: 0)
                tapped = false
            }
            if engine.isRunning { engine.stop() }
            try? audio.setActive(false, options: .notifyOthersOnDeactivation)
            return false
        }
    }

    private func closeMic() {
        // Off the bus before the engine stops, and only once: a second tap on the same bus raises.
        if tapped {
            engine.inputNode.removeTap(onBus: 0)
            tapped = false
        }
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The microphone's loudness, on the main actor: it drives the waveform.
    private func heard(level: Float) {
        guard isRecording else { return }
        report?(.level(level))
    }

    /// The tap itself, built outside the main actor: it runs on the audio thread, where touching
    /// main-actor state traps (`_dispatch_assert_queue_fail`). The buffer goes to the sink, where
    /// every task that is still hearing gets a copy — which is what makes the seams gapless — and the
    /// level is thinned to about 18 reports a second.
    private nonisolated static func tap(_ sink: BufferSink,
                                        onLevel: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        let clock = TapClock()
        return { buffer, _ in
            sink.append(buffer)
            guard clock.tick() else { return }
            onLevel(level(of: buffer))
        }
    }
}

/// The requests the microphone writes into. There is more than one at a seam, so the audio thread
/// reads a copy under a lock instead of reaching into the main actor per buffer.
private final class BufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [SFSpeechAudioBufferRecognitionRequest] = []

    func hold(_ requests: [SFSpeechAudioBufferRecognitionRequest]) {
        lock.lock()
        self.requests = requests
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let requests = self.requests
        lock.unlock()
        for request in requests { request.append(buffer) }
    }
}

/// The tap's loudness as 0…1: -50 dB (a quiet room) to 0 dB, the same scale `MicTap` uses.
private func level(of buffer: AVAudioPCMBuffer) -> Float {
    let n = Int(buffer.frameLength)
    guard n > 0 else { return 0 }
    var sum: Float = 0
    if let samples = buffer.floatChannelData?[0] {
        for i in 0..<n { sum += samples[i] * samples[i] }
    } else if let samples = buffer.int16ChannelData?[0] {
        for i in 0..<n { let v = Float(samples[i]) / 32768; sum += v * v }
    } else {
        return 0
    }
    let db = 10 * log10(max(sum / Float(n), 1e-10))
    return min(1, max(0, (db + 50) / 50))
}

/// One report per `interval`, read from the audio thread: the level goes to the main actor, so it
/// has to be thinned before it crosses.
private final class TapClock: @unchecked Sendable {
    private var last: CFAbsoluteTime = 0
    private let lock = NSLock()

    func tick(_ interval: CFAbsoluteTime = 0.055) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - last >= interval else { return false }
        last = now
        return true
    }
}

private struct SpeechUnavailable: Error {}
