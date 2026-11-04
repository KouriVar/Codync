import CodyncKit
import Foundation
import SwiftUI
import os

private let voiceLog = Logger(subsystem: "com.pokai.Codync", category: "voice")

/// Why the voice sheet stopped early, in the caller's words (`message` is a dictionary key).
public enum VoiceNotice: Sendable, Equatable {
    case permissionDenied
    case microphone
    case unavailable

    public var message: String {
        switch self {
        case .permissionDenied: return "Microphone and speech recognition are off. Open Settings, turn them on, and try again"
        case .microphone: return "The microphone is not available right now. Try again in a moment"
        case .unavailable: return "This device cannot turn speech into text right now"
        }
    }

    /// Only a permission problem is fixed in iOS Settings.
    public var offersSettings: Bool { self == .permissionDenied }
}

/// The microphone's loudness on its own, so 18 readings a second reach the waveform and nothing else.
@MainActor
@Observable
public final class VoiceLevelModel {
    public private(set) var value: Float = 0

    public init() {}

    public func set(_ value: Float) {
        self.value = value
    }
}

/// One voice sheet: hear, pause, read, send. The controller for `VoiceSheetView`; it knows nothing
/// about bots or stores, so the sheet's owner decides who receives what `onSend` hands over.
@MainActor
@Observable
public final class VoiceSession {
    public enum Phase: Equatable {
        /// Nothing is open.
        case idle
        case recording
        /// Held by the pause button with nothing worth sending.
        case paused
        /// Held by the pause button with words to read, correct and send.
        case confirming
        /// A line the sheet shows instead of the words (a permission refusal, say).
        case notice
    }

    /// Seconds the words wait before they send themselves, in automatic mode.
    public static let confirmWindow: Double = 1.5

    public private(set) var phase: Phase = .idle
    /// The waveform's own model: the level never touches the sheet's view tree.
    public let level = VoiceLevelModel()
    /// The words so far.
    public var text = ""
    public private(set) var notice: VoiceNotice?
    /// 1 → 0 across `confirmWindow`, for the send button's ring.
    public private(set) var countdown: Double = 1
    /// The transcript is being corrected: an automatic send waits.
    public var editing = false
    /// The user paused with nothing heard: worth saying, not worth sending.
    public private(set) var notHeard = false
    /// The last send did not reach the bot: the words stay, ready to try again.
    public private(set) var sendFailed = false
    /// A send is in flight: the button waits rather than sending twice.
    public private(set) var sending = false
    /// A photo to send with the words, put there by the sheet's camera.
    public private(set) var attachment: UIImage?
    /// Something is being heard, but too faintly to trust: the sheet asks the user to speak up.
    public private(set) var lowVolume = false

    /// Louder than this is speaking.
    private static let voiceThreshold: Float = 0.18
    /// Quieter than this is the room, and not worth mentioning.
    private static let silentThreshold: Float = 0.04
    /// This long of faint-but-not-silent input earns the "a little quiet" line.
    private static let softAfter: TimeInterval = 3

    /// Hands the words (and any photo) over and reports whether they reached the bot.
    @ObservationIgnored public var onSend: ((String, [OutgoingFile]) async -> Bool)?

    @ObservationIgnored private let transcriber: SpeechTranscriber
    @ObservationIgnored private var timer: Task<Void, Never>?
    /// A send is settling the words: the mic button must not interfere.
    @ObservationIgnored private var ending = false
    /// Bumped by every start and discard, so a slow permission answer can't revive a closed sheet.
    @ObservationIgnored private var generation = 0
    /// Since when the input has been too faint to trust, if it is.
    @ObservationIgnored private var faintSince: Date?

    public init(transcriber: SpeechTranscriber = OnDeviceSpeechTranscriber()) {
        self.transcriber = transcriber
    }

    private var words: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var isIdle: Bool { phase == .idle }
    /// Something to send — words, a photo, or both — and not already on its way.
    public var canSend: Bool {
        (phase == .paused || phase == .confirming) && !sending && !(words.isEmpty && attachment == nil)
    }
    /// Automatic mode: pausing with words starts a send nobody asked for, unless they are corrected.
    public var countingDown: Bool {
        phase == .confirming && !editing && !sendFailed && VoiceSendMode.stored == .automatic
    }
    /// There is something on screen to lose — words or a photo: closing now asks first.
    public var hasWords: Bool { !words.isEmpty || attachment != nil }
    /// Closing now would throw away words the user may still want.
    public var needsConfirm: Bool { hasWords }

    // MARK: what the sheet's buttons do

    /// The voice button: open the microphone and start hearing.
    public func begin() async {
        guard phase == .idle else { return }
        generation += 1
        let generation = generation
        text = ""
        editing = false
        notice = nil
        notHeard = false
        sendFailed = false
        level.set(0)
        // Shown at once: the mic takes a moment to open.
        phase = .recording
        let allowed = await transcriber.permission()
        guard generation == self.generation, phase == .recording else { return }
        guard allowed != .denied else { return stop(with: .permissionDenied) }
        guard allowed != .unavailable else { return stop(with: .unavailable) }
        transcriber.locale = Locale(identifier: VoiceLanguage.stored.localeIdentifier)
        do {
            try transcriber.start { [weak self] event in self?.apply(event) }
        } catch {
            stop(with: .microphone)
            return
        }
        Haptics.impact()
    }

    /// The pause/continue button: pausing settles what was heard (and offers it to send), and
    /// continuing picks the recording up again.
    public func toggleMicrophone() {
        guard !ending else { return }
        switch phase {
        case .recording:
            transcriber.pause()
            level.set(0)
            faintSince = nil
            lowVolume = false
            Haptics.impact()
            settlePaused()
        case .paused, .confirming:
            // Continuing cancels an automatic send: the user wants to say more.
            stopTimer()
            countdown = 0
            notHeard = false
            guard transcriber.resume() else {
                stop(with: .microphone)
                return
            }
            phase = .recording
            Haptics.impact()
        default:
            break
        }
    }

    /// The camera's photo: shown under the title, sent with the words, and removable until then.
    public func attach(_ image: UIImage?) {
        attachment = image
        if image != nil, words.isEmpty, phase != .confirming {
            // Nothing said yet: the words area is where the photo's message will come from.
            phase = .confirming
        }
        countdown = 0
        stopTimer()
        Haptics.impact()
    }

    /// The keyboard button: stop hearing and put what was heard into the field, ready to type on.
    public func startTyping() {
        guard phase == .recording || phase == .paused || phase == .confirming else { return }
        if phase == .recording {
            transcriber.pause()
            level.set(0)
            faintSince = nil
            lowVolume = false
        }
        stopTimer()
        countdown = 0
        notHeard = false
        editing = true
        phase = .confirming
        Haptics.impact()
    }

    /// Send now: the button, and the end of an automatic countdown.
    public func sendNow() async {
        guard canSend else { return }
        stopTimer()
        sending = true
        sendFailed = false
        // The recognizer's last words land a moment after the microphone closes.
        try? await Task.sleep(for: .milliseconds(200))
        let toSend = words
        guard !toSend.isEmpty || attachment != nil else {
            sending = false
            notHeard = true
            phase = .paused
            countdown = 0
            return
        }
        voiceLog.info("sending \(toSend.count, privacy: .public) chars")
        let files = attachment
            .flatMap { $0.jpegData(compressionQuality: 0.85) }
            .map { [OutgoingFile(name: "photo.jpg", data: $0)] } ?? []
        let delivered = await onSend?(toSend, files) ?? false
        sending = false
        guard delivered else {
            // Kept: the words stay on screen and the button tries again.
            sendFailed = true
            countdown = 0
            Haptics.notification()
            return
        }
        Haptics.notification()
        reset()
        phase = .idle
    }

    /// Tapping the words: correct them; correcting stops an automatic send.
    public func startEditing() {
        guard canSend else { return }
        editing = true
        stopTimer()
        countdown = 0
        Haptics.impact()
    }

    /// The sheet is closing: stop hearing and drop this recording. Nothing is sent.
    public func discard() {
        guard phase != .idle else { return }
        generation += 1
        stopTimer()
        transcriber.cancel()
        reset()
        phase = .idle
    }

    // MARK: internals

    /// Pausing with words is the moment they become sendable; pausing without any says so instead.
    private func settlePaused() {
        editing = false
        sendFailed = false
        // The whole text, not just what earlier tasks committed: this is the decision that used to
        // come out as "did not catch that" while the words were there.
        voiceLog.info("pause settled with \(self.words.count, privacy: .public) chars, empty=\(self.words.isEmpty, privacy: .public)")
        guard !words.isEmpty else {
            notHeard = true
            phase = .paused
            return
        }
        notHeard = false
        phase = .confirming
        if VoiceSendMode.stored == .automatic { startCountdown() } else { countdown = 0 }
    }

    private func reset() {
        stopTimer()
        attachment = nil
        faintSince = nil
        lowVolume = false
        text = ""
        editing = false
        notice = nil
        notHeard = false
        sendFailed = false
        sending = false
        countdown = 0
        level.set(0)
    }

    /// A missed `begin` (no permission, no microphone) waits here instead of hanging.
    private func stop(with notice: VoiceNotice) {
        generation += 1
        ending = false
        stopTimer()
        transcriber.cancel()
        level.set(0)
        text = ""
        editing = false
        self.notice = notice
        phase = .notice
    }

    private func apply(_ event: SpeechEvent) {
        switch event {
        case let .level(value):
            guard phase == .recording else { return }
            level.set(value)
            trackFaint(value)
        case let .partial(words):
            guard phase == .recording || phase == .paused || phase == .confirming else { return }
            text = words
            // Speaking again takes back the "did not catch that" line.
            if !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { notHeard = false }
        case let .failed(reason):
            stop(with: reason == .permissionDenied ? .permissionDenied
                 : reason == .microphone ? .microphone : .unavailable)
        }
    }

    /// Hearing something, but faintly: after a few seconds of it, say so. A silent room says nothing,
    /// and a voice that comes back up takes the line away.
    private func trackFaint(_ value: Float) {
        if value >= Self.voiceThreshold {
            faintSince = nil
            if lowVolume { lowVolume = false }
        } else if value <= Self.silentThreshold {
            faintSince = nil
            if lowVolume { lowVolume = false }
        } else {
            let since = faintSince ?? Date.now
            faintSince = since
            let faint = Date.now.timeIntervalSince(since) >= Self.softAfter
            if faint != lowVolume { lowVolume = faint }
        }
    }

    private func startCountdown() {
        stopTimer()
        countdown = 1
        timer = Task { @MainActor [weak self] in
            let step = 0.05
            var left = Self.confirmWindow
            while !Task.isCancelled, left > 0 {
                try? await Task.sleep(for: .seconds(step))
                guard let self, !Task.isCancelled, self.countingDown else { return }
                left -= step
                self.countdown = max(0, left / Self.confirmWindow)
            }
            guard let self, !Task.isCancelled, self.countingDown else { return }
            await self.sendNow()
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
