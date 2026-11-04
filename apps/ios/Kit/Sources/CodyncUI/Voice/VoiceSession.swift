import CodyncKit
import Foundation
import SwiftUI

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

/// One voice sheet: hear, pause, end, read, send. The controller for `VoiceSheetView`; it knows
/// nothing about bots or stores, so the sheet's owner decides who receives what `onSend` hands over.
@MainActor
@Observable
public final class VoiceSession {
    public enum Phase: Equatable {
        /// Nothing is open.
        case idle
        case recording
        case paused
        /// The words are in the sheet, waiting to be read or corrected.
        case confirming
        /// A line the sheet shows instead of the words (a permission refusal, say).
        case notice
    }

    /// Seconds the words wait before they send themselves, in automatic mode.
    public static let confirmWindow: Double = 1.5

    public private(set) var phase: Phase = .idle
    public private(set) var level: Float = 0
    /// The words so far while recording, the words to send afterwards.
    public var text = ""
    public private(set) var notice: VoiceNotice?
    /// 1 → 0 across `confirmWindow`, for the send button's ring.
    public private(set) var countdown: Double = 1
    /// The transcript is being corrected: the countdown holds.
    public var editing = false
    /// The user ended with nothing heard: worth saying, not worth sending.
    public private(set) var notHeard = false
    /// The last send did not reach the bot: the words stay, ready to try again.
    public private(set) var sendFailed = false
    /// A send is in flight: the button waits rather than sending twice.
    public private(set) var sending = false

    /// Hands the words over and reports whether they reached the bot.
    @ObservationIgnored public var onSend: ((String) async -> Bool)?

    @ObservationIgnored private let transcriber: SpeechTranscriber
    @ObservationIgnored private var timer: Task<Void, Never>?
    /// `finish` is waiting on the recognizer: the mic button must not start another one.
    @ObservationIgnored private var ending = false
    /// Bumped by every start and stop, so a slow permission answer can't revive a cancelled sheet.
    @ObservationIgnored private var generation = 0

    public init(transcriber: SpeechTranscriber = OnDeviceSpeechTranscriber()) {
        self.transcriber = transcriber
    }

    public var isIdle: Bool { phase == .idle }
    /// There is something to send, and it isn't already on its way.
    public var canSend: Bool {
        phase == .confirming && !sending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Automatic mode: the words send themselves unless the user is correcting them.
    public var countingDown: Bool { phase == .confirming && !editing && !sendFailed && VoiceSendMode.stored == .automatic }

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
        level = 0
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

    /// Pause while hearing, hear again while paused.
    public func toggleMicrophone() {
        // The words are already on their way out: the button does nothing until they land.
        guard !ending else { return }
        switch phase {
        case .recording:
            transcriber.pause()
            phase = .paused
            level = 0
            Haptics.impact()
        case .paused:
            notHeard = false
            if transcriber.resume() {
                phase = .recording
            } else {
                stop(with: .microphone)
                return
            }
            Haptics.impact()
        default:
            break
        }
    }

    /// End the recording and make the words ready: nothing heard says so, and the mic stays usable.
    public func end() async {
        guard phase == .recording || phase == .paused, !ending else { return }
        ending = true
        stopTimer()
        level = 0
        Haptics.impact()
        let words = await transcriber.finish()
        ending = false
        guard phase != .idle else { return }
        text = words
        sendFailed = false
        guard !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Not heard: the sheet stays, the words area says so, and the mic can go again.
            notHeard = true
            editing = false
            phase = .paused
            return
        }
        notHeard = false
        phase = .confirming
        // Automatic mode: the ring runs and the words go; manual waits for the button.
        if VoiceSendMode.stored == .automatic { startCountdown() } else { countdown = 0 }
    }

    /// The red button: stop now, keep nothing, and let the sheet close.
    public func cancel() {
        generation += 1
        ending = false
        stopTimer()
        transcriber.cancel()
        // A light tap: cancelling is the quiet way out.
        Haptics.impact()
        reset()
        phase = .idle
    }

    /// Send now: the button, and the end of the countdown.
    public func sendNow() async {
        guard canSend else { return }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        stopTimer()
        sending = true
        sendFailed = false
        let delivered = await onSend?(words) ?? false
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
        guard phase == .confirming, !sending else { return }
        editing = true
        stopTimer()
        countdown = 0
        Haptics.impact()
    }

    public func dismissNotice() {
        stopTimer()
        transcriber.cancel()
        notice = nil
        phase = .idle
    }

    // MARK: internals

    private func reset() {
        stopTimer()
        text = ""
        editing = false
        notice = nil
        notHeard = false
        sendFailed = false
        sending = false
        level = 0
        countdown = 0
    }

    /// A missed `begin` (no permission, no microphone) waits here instead of hanging.
    private func stop(with notice: VoiceNotice) {
        generation += 1
        ending = false
        stopTimer()
        transcriber.cancel()
        level = 0
        text = ""
        editing = false
        self.notice = notice
        phase = .notice
    }

    private func apply(_ event: SpeechEvent) {
        switch event {
        case let .level(value):
            guard phase == .recording else { return }
            level = value
        case let .partial(words):
            guard phase == .recording || phase == .paused else { return }
            text = words
        case let .failed(reason):
            stop(with: reason == .permissionDenied ? .permissionDenied
                 : reason == .microphone ? .microphone : .unavailable)
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
