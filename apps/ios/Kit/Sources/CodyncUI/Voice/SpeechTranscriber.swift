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
/// One recognizer task lives for about a minute, so a recording is a chain of tasks: when one hands
/// back its last words the next starts on the same microphone and the text carries on. The user
/// hears one continuous recording.
@MainActor
public final class OnDeviceSpeechTranscriber: SpeechTranscriber {
    public var locale: Locale
    public private(set) var isRecording = false

    /// Built on the first recording: an AVAudioEngine is heavy enough to be felt when the home draws.
    private lazy var engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    /// Whichever request is current; the audio thread reads it through `sink`.
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let sink = BufferSink()
    private var report: (@MainActor @Sendable (SpeechEvent) -> Void)?
    /// Bumped by every start, pause and cancel, so late results from an older recording are dropped.
    private var generation = 0
    /// A tap is installed on the input node; only then may it be taken off.
    private var tapped = false
    /// Words from tasks that already ended, and the one still running: together they are the text.
    private var committed: [String] = []
    private var partial = ""
    /// `finish` waits here for the recognizer's last word, unless it takes too long.
    private var settling: CheckedContinuation<Void, Never>?

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
    }

    /// Everything heard so far, one space between task boundaries.
    private var words: String {
        (committed + (partial.isEmpty ? [] : [partial]))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        partial = ""
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
    }

    public func pause() {
        guard isRecording else { return }
        isRecording = false
        closeMic()
        report?(.level(0))
    }

    @discardableResult
    public func resume() -> Bool {
        guard !isRecording, request != nil || task != nil else { return false }
        guard openMic() else {
            cancel()
            report?(.failed(.microphone))
            return false
        }
        isRecording = true
        // The task may have run out of its minute while we were paused.
        if task == nil { startTask() }
        return true
    }

    public func finish() async -> String {
        guard request != nil || task != nil else {
            let said = words
            release()
            return said
        }
        isRecording = false
        closeMic()
        request?.endAudio()
        // The recognizer's last word arrives a moment after the audio ends.
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

    // MARK: one recognizer task at a time

    /// Starts hearing with a fresh request: the first task, and every replacement after it.
    private func startTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        // On device when the phone can: nothing said leaves the phone.
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request
        // The audio thread appends to whatever is in the sink, so a swap never loses a buffer.
        sink.hold(request)
        let generation = generation
        task = recognizer.recognitionTask(with: request,
                                          resultHandler: Self.results(generation: generation, into: self))
    }

    /// The recognizer calls this on its own queue, so it's built outside the main actor and hops
    /// back before touching anything (an inferred main-actor closure called off the main thread
    /// traps in `_dispatch_assert_queue_fail`).
    private nonisolated static func results(generation: Int, into transcriber: OnDeviceSpeechTranscriber)
        -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard transcriber.generation == generation else { return }
                if let text { transcriber.recognized(text) }
                if final || failed { transcriber.taskEnded() }
            }
        }
    }

    private func recognized(_ text: String) {
        partial = text
        report?(.partial(words))
    }

    /// A task reached its minute, or failed: keep its words and, while still listening, carry on
    /// with a new one so the recording never stops under the user.
    private func taskEnded() {
        if !partial.isEmpty { committed.append(partial) }
        partial = ""
        task = nil
        request = nil
        report?(.partial(words))
        if isRecording {
            startTask()
        } else {
            settle()
        }
    }

    /// Wakes `finish` once; anything the recognizer says afterwards is dropped.
    private func settle() {
        settling?.resume()
        settling = nil
    }

    private func release() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        sink.hold(nil)
        recognizer = nil
        closeMic()
        report?(.level(0))
        report = nil
        committed = []
        partial = ""
        isRecording = false
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
    /// main-actor state traps (`_dispatch_assert_queue_fail`). The buffer goes straight to the sink
    /// the current request is in, and the level is thinned to about 18 reports a second — one per
    /// audio buffer would be nearly 50 main-thread hops a second for a waveform nobody sees move
    /// that fast.
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

/// The request the microphone writes into. It changes whenever a task runs out of time, so the
/// audio thread reads a copy under a lock instead of reaching into the main actor per buffer.
private final class BufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func hold(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = self.request
        lock.unlock()
        request?.append(buffer)
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
