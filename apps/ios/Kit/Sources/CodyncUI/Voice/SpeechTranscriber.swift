import AVFoundation
import CodyncKit
import Foundation
import os
import Speech

private let voiceLog = Logger(subsystem: "com.pokai.Codync", category: "voice")

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
    /// `pause`, `finish` or `cancel`. Throws when the microphone can't be used. The audio session and
    /// the engine are opened off the main actor, so awaiting this never freezes the UI.
    func start(_ report: @escaping @MainActor @Sendable (SpeechEvent) -> Void) async throws
    /// Stops hearing and keeps the words so far, so `resume` can carry on.
    func pause()
    /// Hears again after `pause`.
    @discardableResult func resume() async -> Bool
    /// Ends the recording and gives the final words (what was heard so far if the recognizer stalls).
    func finish() async -> String
    /// Drops everything at once.
    func cancel()
}

/// The phone's own recognizer (SFSpeechRecognizer), on device when the phone supports it.
///
/// One recognizer task hears a recording at a time, as C0152 did: that path is the one proven to
/// transcribe on the phone. When a task ends — it gives up, or runs out of its ~1 minute — its words
/// are kept and, if the task ran for longer than `restartAfter`, one new task carries on from there.
/// A task that dies sooner than that is *not* restarted, so a recognizer that refuses immediately
/// can't turn into a restart loop that hears nothing.
///
/// The C0154 relay (start the next task before closing the last, both on the microphone, seams
/// deduplicated) is still here behind `relayTasks`, off by default until it is proven on device.
@MainActor
public final class OnDeviceSpeechTranscriber: SpeechTranscriber {
    /// Overlapping task relay. Off: one task at a time, the C0152 path.
    public static var relayTasks = false
    /// A task that lasted less than this is not restarted: something is wrong with it, not the mic.
    /// Short enough that a sentence spoken after a natural final still gets its own task.
    private static let restartAfter: TimeInterval = 1.5
    /// A task is replaced this long after it starts when the relay is on.
    private static let taskLifetime: TimeInterval = 44
    /// How long the old and the new task both hear the microphone in relay mode.
    private static let overlap: Duration = .milliseconds(300)

    public var locale: Locale
    public private(set) var isRecording = false

    /// The microphone's hardware, on a queue of its own: the session, the engine and its tap.
    private let mic = MicStack()
    private var recognizer: SFSpeechRecognizer?
    /// The request hearing the microphone now, and (relay only) the one finishing up.
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var closing: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Relay only: both requests read the microphone through this.
    private let sink = BufferSink()
    /// On device unless a first task fails at once: a phone without the language's on-device model
    /// answers an on-device request with an error, and the network recognizer is better than none.
    private var preferOnDevice = true
    private var report: (@MainActor @Sendable (SpeechEvent) -> Void)?
    /// Bumped by every start and cancel, so late results from an older recording are dropped.
    private var generation = 0
    /// Which task the results belong to: the closing one in relay mode must not overwrite the new.
    private var taskID = 0
    /// Words of tasks that already ended, and of the one running: together they are the text.
    private var committed: [String] = []
    private var partial = ""
    /// Relay only: the closing task's last words, until it hands them over.
    private var fading = ""
    private var taskStartedAt = Date.now
    private var newestTaskAt = Date.now
    private var rotation: Task<Void, Never>?
    private var stats: Task<Void, Never>?
    /// `finish` waits here for the recognizer's last word, unless it takes too long.
    private var settling: CheckedContinuation<Void, Never>?

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
    }

    /// Everything heard so far, the seams between tasks deduplicated.
    private var words: String {
        Self.join(committed + (fading.isEmpty ? [] : [fading]) + (partial.isEmpty ? [] : [partial]))
    }

    // MARK: permission

    public func permission() async -> SpeechPermission {
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else { return .denied }
        guard await Self.authorized() else { return .denied }
        // Made here once and kept for `start`, which used to make a second one of its own.
        guard let recognizer = recognizer(for: self.locale), recognizer.isAvailable else { return .unavailable }
        return .granted
    }

    /// The recognizer for this locale: the one already made, or a new one that `start` then reuses.
    private func recognizer(for locale: Locale) -> SFSpeechRecognizer? {
        if let recognizer, self.locale == locale { return recognizer }
        let made = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
        recognizer = made
        return made
    }

    private nonisolated static func authorized() async -> Bool {
        await withCheckedContinuation { done in
            SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0 == .authorized) }
        }
    }

    // MARK: recording

    public func start(_ report: @escaping @MainActor @Sendable (SpeechEvent) -> Void) async throws {
        cancel()
        generation += 1
        let opening = generation
        self.report = report
        committed = []
        let locale = self.locale
        guard let recognizer = recognizer(for: locale), recognizer.isAvailable else {
            voiceLog.error("no recognizer for \(locale.identifier, privacy: .public)")
            self.report = nil
            throw SpeechUnavailable()
        }
        self.recognizer = recognizer
        voiceLog.info("""
            start locale=\(locale.identifier, privacy: .public) \
            onDevice=\(recognizer.supportsOnDeviceRecognition, privacy: .public) \
            relay=\(Self.relayTasks, privacy: .public)
            """)
        startTask()
        guard let request else {
            cancel()
            throw SpeechUnavailable()
        }
        // The session and the engine are opened on the microphone's own queue: awaiting here frees
        // the main actor for the bar's animation instead of freezing it for the hardware.
        guard await openMic(with: request) else {
            cancel()
            throw SpeechUnavailable()
        }
        // Cancelled while it was opening: the queue has already been told to close it again.
        guard generation == opening else { return }
        isRecording = true
        watchRotation(generation: generation)
        watchLevel()
    }

    public func pause() {
        guard isRecording else { return }
        isRecording = false
        closeMic()
        report?(.level(0))
        voiceLog.info("pause after \(Int(self.words.count)) chars")
    }

    @discardableResult
    public func resume() async -> Bool {
        guard !isRecording else { return false }
        // Every task may have ended while we were paused: hearing again needs one to write into.
        if request == nil { startTask() }
        guard let request else {
            cancel()
            report?(.failed(.microphone))
            return false
        }
        let resuming = generation
        guard await openMic(with: request) else {
            cancel()
            report?(.failed(.microphone))
            return false
        }
        // Paused or cancelled while it was opening: the queue has already been told to close it.
        guard generation == resuming else { return false }
        isRecording = true
        newestTaskAt = .now
        voiceLog.info("resume with \(Int(self.words.count)) chars so far")
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
        closing?.endAudio()
        // The recognizer's last word arrives a moment after the audio ends.
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            settling = done
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(1200))
                self?.settle()
            }
        }
        let said = words
        voiceLog.info("finish with \(said.count, privacy: .public) chars")
        release()
        return said
    }

    public func cancel() {
        generation += 1
        release()
        settle()
    }

    // MARK: one task at a time

    /// Starts hearing with a fresh request; in relay mode the previous one keeps hearing for a beat.
    private func startTask() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        // On device when the phone can: nothing said leaves the phone.
        if recognizer.supportsOnDeviceRecognition, preferOnDevice { request.requiresOnDeviceRecognition = true }
        taskID += 1
        let id = taskID
        let generation = generation
        self.request = request
        taskStartedAt = .now
        newestTaskAt = .now
        partial = ""
        refreshSink()
        task = recognizer.recognitionTask(with: request,
                                          resultHandler: Self.results(id: id, generation: generation, into: self))
        voiceLog.info("task \(id, privacy: .public) started")
        // The tap was bound to the request it was installed with: a new one needs a new tap.
        if !Self.relayTasks { retap(on: request) }
    }

    /// The next task hears the microphone before the last one stops: whichever buffer a seam falls
    /// between, one of them has it. The old one is closed a beat later and its words folded in.
    private func rotate() {
        guard isRecording, let old = request else { return }
        closing = old
        startTask()
        refreshSink()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.overlap)
            self?.closeClosing()
        }
    }

    private func closeClosing() {
        closing?.endAudio()
        refreshSink()
    }

    /// Relay mode: whatever is still hearing goes to the microphone; a closing task gets nothing more.
    private func refreshSink() {
        guard Self.relayTasks else { return }
        sink.hold([closing, request].compactMap { $0 })
    }

    private func watchRotation(generation: Int) {
        rotation?.cancel()
        guard Self.relayTasks else { return }
        rotation = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.generation == generation, self.isRecording else { return }
                if Date.now.timeIntervalSince(self.newestTaskAt) > Self.taskLifetime { self.rotate() }
            }
        }
    }

    // MARK: what the recognizer says

    /// The recognizer calls this on its own queue, so it's built outside the main actor and hops
    /// back before touching anything (an inferred main-actor closure called off the main thread
    /// traps in `_dispatch_assert_queue_fail`).
    private nonisolated static func results(id: Int, generation: Int, into transcriber: OnDeviceSpeechTranscriber)
        -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            Task { @MainActor in
                guard transcriber.generation == generation else { return }
                transcriber.heard(id: id, text: text, final: final, error: error)
            }
        }
    }

    private func heard(id: Int, text: String?, final: Bool, error: (any Error)?) {
        let isCurrent = id == taskID
        if let text, !text.isEmpty {
            if isCurrent { partial = text } else { fading = text }
            report?(.partial(words))
        }
        guard final || error != nil else { return }
        let lived = Date.now.timeIntervalSince(taskStartedAt)
        if let error {
            let ns = error as NSError
            voiceLog.error("task \(id, privacy: .public) error \(ns.domain, privacy: .public)/\(ns.code, privacy: .public) after \(lived, format: .fixed(precision: 1), privacy: .public)s: \(ns.localizedDescription, privacy: .public)")
        } else {
            voiceLog.info("task \(id, privacy: .public) final after \(lived, format: .fixed(precision: 1), privacy: .public)s, \(self.words.count, privacy: .public) chars")
        }
        if isCurrent { taskEnded(lived: lived, failed: error != nil) } else { foldClosing() }
    }

    /// The current task is done. Its words stay; if it lived long enough to have run into the
    /// recognizer's limit, one new task carries on. A task that dies at once is left alone: restarting
    /// it would only spin.
    private func taskEnded(lived: TimeInterval, failed: Bool) {
        if !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { committed.append(partial) }
        partial = ""
        task = nil
        request = nil
        report?(.partial(words))
        // A task that failed at once on an on-device request gets one retry on the network model.
        if failed, isRecording, lived <= Self.restartAfter, preferOnDevice {
            preferOnDevice = false
            voiceLog.info("on-device recognition failed at once: retrying without it")
            startTask()
            return
        }
        guard isRecording, lived > Self.restartAfter else {
            if isRecording {
                voiceLog.info("task died after \(lived, format: .fixed(precision: 1), privacy: .public)s: not restarted")
            }
            settle()
            return
        }
        startTask()
    }

    private func foldClosing() {
        if !fading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { committed.append(fading) }
        fading = ""
        closing = nil
        report?(.partial(words))
    }

    /// Wakes `finish` once; anything the recognizer says afterwards is dropped.
    private func settle() {
        settling?.resume()
        settling = nil
    }

    private func release() {
        rotation?.cancel()
        rotation = nil
        stats?.cancel()
        stats = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        closing?.endAudio()
        closing = nil
        sink.hold([])
        recognizer = nil
        closeMic()
        report?(.level(0))
        report = nil
        committed = []
        partial = ""
        fading = ""
        isRecording = false
    }

    // MARK: the seam

    /// Tasks end and start mid-sentence, so their words overlap: drop the longest tail of the text so
    /// far that repeats the head of the next one.
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

    /// Opens the microphone on its own queue and answers whether it opened. The main actor only waits.
    private func openMic(with request: SFSpeechAudioBufferRecognitionRequest) async -> Bool {
        await mic.open(tap: TapBox(block(for: request)))
    }

    /// While the engine runs, the tap follows the request it feeds.
    private func retap(on request: SFSpeechAudioBufferRecognitionRequest) {
        mic.retap(TapBox(block(for: request)))
    }

    /// Relay mode feeds both requests through the sink; otherwise the tap writes to the one request
    /// directly, exactly as C0152 did.
    private func block(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        let onLevel: @Sendable (Float) -> Void = { [weak self] level in
            Task { @MainActor in self?.heard(level: level) }
        }
        let counter = TapStats.shared
        return Self.relayTasks
            ? Self.tap(into: sink, counting: counter, onLevel: onLevel)
            : Self.tap(into: request, counting: counter, onLevel: onLevel)
    }

    private func closeMic() {
        // Taken off the bus before the engine stops, and only once: a second tap on the same bus
        // raises. The queue keeps that in order with whatever open is still finishing.
        mic.close()
    }

    /// The microphone's loudness, on the main actor: it drives the waveform.
    private func heard(level: Float) {
        guard isRecording else { return }
        report?(.level(level))
    }

    /// A buffer a second, logged: whether the microphone is really reaching the recognizer.
    private func watchLevel() {
        stats?.cancel()
        let counter = TapStats.shared
        stats = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRecording else { return }
                let count = counter.take()
                let feeding = Self.relayTasks ? "sink" : (self.request == nil ? "nothing" : "request")
                let chars = self.words.count
                voiceLog.debug("buffers \(count, privacy: .public)/s, feeding \(feeding, privacy: .public), \(chars, privacy: .public) chars")
            }
        }
    }

    /// The tap itself, built outside the main actor: it runs on the audio thread, where touching
    /// main-actor state traps (`_dispatch_assert_queue_fail`).
    private nonisolated static func tap(into request: SFSpeechAudioBufferRecognitionRequest,
                                        counting counter: TapStats,
                                        onLevel: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        let clock = TapClock()
        return { buffer, _ in
            counter.add()
            request.append(buffer)
            guard clock.tick() else { return }
            onLevel(level(of: buffer))
        }
    }

    private nonisolated static func tap(into sink: BufferSink, counting counter: TapStats,
                                        onLevel: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        let clock = TapClock()
        return { buffer, _ in
            counter.add()
            sink.append(buffer)
            guard clock.tick() else { return }
            onLevel(level(of: buffer))
        }
    }
}

/// One tap block, carried across to the microphone's queue. `AVAudioNodeTapBlock` is not Sendable on
/// its own; the block it wraps is written to run on the audio thread and touches no actor state.
private struct TapBox: @unchecked Sendable {
    let block: AVAudioNodeTapBlock

    init(_ block: @escaping AVAudioNodeTapBlock) { self.block = block }
}

/// The microphone's hardware, on a queue of its own: the audio session, the engine and its tap.
///
/// Putting a `.playAndRecord` session in place and starting an `AVAudioEngine` take tens of
/// milliseconds, and they used to be spent on the main actor — exactly where the home's voice capsule
/// is animating. They happen here instead. One serial queue owns everything that touches these
/// objects, so nothing is created on one thread and stopped on another; callers only wait for the
/// answer, and the main actor is free while they do.
private final class MicStack: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.pokai.Codync.voice.mic", qos: .userInitiated)
    /// Made on this queue the first time a recording opens, so the home never pays for it.
    private var engine: AVAudioEngine?
    /// The input's format, kept so a tap can be swapped without reopening the session.
    private var format: AVAudioFormat?
    /// A tap is installed on the input node; only then may it be taken off.
    private var tapped = false

    /// Opens the microphone: record category, active session, the tap, the engine running.
    func open(tap: TapBox) async -> Bool {
        await withCheckedContinuation { done in
            queue.async { done.resume(returning: self.openNow(tap: tap.block)) }
        }
    }

    /// A new request needs a new tap; the session and the engine stay where they are.
    func retap(_ tap: TapBox) {
        queue.async {
            guard self.tapped, let format = self.format, let engine = self.engine else { return }
            engine.inputNode.removeTap(onBus: 0)
            engine.inputNode.installTap(onBus: 0, bufferSize: 2048, format: format, block: tap.block)
        }
    }

    /// Stops the engine and gives the session back. Queued behind any open still finishing, so the two
    /// never touch the engine at once.
    func close() {
        queue.async {
            if let engine = self.engine {
                if self.tapped {
                    engine.inputNode.removeTap(onBus: 0)
                    self.tapped = false
                }
                if engine.isRunning { engine.stop() }
            }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func openNow(tap: @escaping AVAudioNodeTapBlock) -> Bool {
        let audio = AVAudioSession.sharedInstance()
        do {
            // The session has to be in a record category and active before the tap goes on.
            try audio.setCategory(.playAndRecord, mode: .default,
                                  options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try audio.setActive(true)
            let engine: AVAudioEngine
            if let existing = self.engine {
                engine = existing
            } else {
                // An AVAudioEngine is heavy enough to be felt: it is made here, not while the home draws.
                let made = AVAudioEngine()
                self.engine = made
                engine = made
            }
            let input = engine.inputNode
            // The buffer's own format: a tap in any other format is refused or raises.
            let format = try MicTap.format(of: input)
            self.format = format
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 2048, format: format, block: tap)
            tapped = true
            engine.prepare()
            try engine.start()
            voiceLog.info("microphone open, \(format.sampleRate, privacy: .public) Hz")
            return true
        } catch {
            voiceLog.error("microphone failed: \(error.localizedDescription, privacy: .public)")
            if tapped, let engine {
                engine.inputNode.removeTap(onBus: 0)
                tapped = false
            }
            if let engine, engine.isRunning { engine.stop() }
            try? audio.setActive(false, options: .notifyOthersOnDeactivation)
            return false
        }
    }
}

/// How many buffers the microphone handed over: one number a second is enough to tell whether the
/// tap is wired to a request at all.
private final class TapStats: @unchecked Sendable {
    static let shared = TapStats()
    private let lock = NSLock()
    private var count = 0

    func add() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    func take() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let taken = count
        count = 0
        return taken
    }
}

/// The requests the microphone writes into in relay mode: there is more than one at a seam.
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
