import CodyncKit
import Foundation
import SwiftUI

/// Why the voice capsule stopped early, in the caller's words (`message` is a dictionary key).
public enum VoiceNotice: Sendable, Equatable {
    case permissionDenied
    case microphone
    case unavailable
    /// Nothing was recognized: sending that would be sending an empty message.
    case notEnough

    public var message: String {
        switch self {
        case .permissionDenied: return "Microphone and speech recognition are off. Open Settings, turn them on, and try again"
        case .microphone: return "The microphone is not available right now. Try again in a moment"
        case .unavailable: return "This device cannot turn speech into text right now"
        case .notEnough: return "Did not catch that"
        }
    }

    /// Only a permission problem is fixed in iOS Settings.
    public var offersSettings: Bool { self == .permissionDenied }
}

/// One voice capsule: hear, pause, end, confirm, send. The controller for `VoiceCapsule`; it knows
/// nothing about bots or stores, so the home decides who receives what `onSend` hands over.
@MainActor
@Observable
public final class VoiceSession {
    public enum Phase: Equatable {
        /// The bottom bar is showing.
        case idle
        case recording
        case paused
        /// The words are in the capsule, the countdown is running.
        case confirming
        /// A line in the capsule (a permission refusal, "没听清") instead of the controls.
        case notice
    }

    /// Seconds the confirmed words wait before they send themselves.
    public static let confirmWindow: Double = 1.5

    public private(set) var phase: Phase = .idle
    public private(set) var level: Float = 0
    /// The words so far while recording, the confirmed words afterwards.
    public var text = ""
    public private(set) var notice: VoiceNotice?
    /// 1 → 0 across `confirmWindow`, for the send button's ring.
    public private(set) var countdown: Double = 1
    /// The transcript is being corrected: the countdown holds.
    public var editing = false
    /// Hands the final words over; the home sends them to the lead bot.
    @ObservationIgnored public var onSend: ((String) -> Void)?

    @ObservationIgnored private let transcriber: SpeechTranscriber
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var typed = ""
    /// Bumped by every start and stop, so a slow permission answer can't revive a cancelled capsule.
    @ObservationIgnored private var generation = 0

    public init(transcriber: SpeechTranscriber = OnDeviceSpeechTranscriber()) {
        self.transcriber = transcriber
    }

    public var isIdle: Bool { phase == .idle }
    /// The capsule shows as soon as the bar steps aside, so it animates in while the mic opens.
    public var isPresented: Bool { phase != .idle }

    // MARK: what the capsule's buttons do

    /// The voice button: open the microphone and start hearing.
    public func begin() async {
        guard phase == .idle else { return }
        generation += 1
        let generation = generation
        text = ""
        typed = ""
        editing = false
        notice = nil
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

    /// The mic button: pause while hearing, hear again while paused, end and confirm while paused.
    public func toggleMicrophone() {
        switch phase {
        case .recording:
            transcriber.pause()
            phase = .paused
            level = 0
            Haptics.impact()
        case .paused:
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

    /// The end button (or two seconds of silence): fix the words and start the countdown.
    public func end() async {
        guard phase == .recording || phase == .paused else { return }
        stopTimer()
        level = 0
        Haptics.impact()
        let words = await transcriber.finish()
        guard phase != .idle else { return }
        text = words
        if words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stop(with: .notEnough, after: Self.confirmWindow)
            return
        }
        phase = .confirming
        startCountdown()
    }

    /// The red button: stop now, keep nothing.
    public func cancel() {
        generation += 1
        stopTimer()
        transcriber.cancel()
        // A light tap: cancelling is the quiet way out.
        Haptics.impact()
        text = ""
        typed = ""
        editing = false
        notice = nil
        level = 0
        phase = .idle
    }

    /// The words send now, without waiting out the countdown.
    public func sendNow() {
        guard phase == .confirming else { return }
        let words = (editing ? typed : text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return stop(with: .notEnough, after: Self.confirmWindow) }
        stopTimer()
        phase = .idle
        text = ""
        typed = ""
        editing = false
        onSend?(words)
    }

    /// Tapping the words: correct them; the countdown holds until they send or the capsule closes.
    public func startEditing() {
        guard phase == .confirming else { return }
        typed = text
        editing = true
        stopTimer()
        Haptics.impact()
    }

    /// A missed `begin` (nothing heard, no permission) waits here instead of hanging.
    private func stop(with notice: VoiceNotice, after: Double? = nil) {
        generation += 1
        stopTimer()
        transcriber.cancel()
        level = 0
        text = ""
        editing = false
        self.notice = notice
        phase = .notice
        if let after {
            timer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(after))
                guard !Task.isCancelled else { return }
                self?.dismissNotice()
            }
        }
    }

    public func dismissNotice() {
        stopTimer()
        transcriber.cancel()
        notice = nil
        phase = .idle
    }

    // MARK: internals

    private func apply(_ event: SpeechEvent) {
        switch event {
        case let .level(value):
            guard phase == .recording else { return }
            level = value
        case let .partial(words):
            guard phase == .recording || phase == .paused else { return }
            text = words
        case .silence:
            guard phase == .recording else { return }
            Task { await end() }
        case let .failed(reason):
            stop(with: reason == .permissionDenied ? .permissionDenied : reason == .microphone ? .microphone : .unavailable)
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
                guard let self, !Task.isCancelled, self.phase == .confirming, !self.editing else { return }
                left -= step
                self.countdown = max(0, left / Self.confirmWindow)
            }
            guard let self, !Task.isCancelled, self.phase == .confirming, !self.editing else { return }
            self.sendNow()
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
