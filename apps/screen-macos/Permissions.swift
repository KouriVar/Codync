import AppKit
import ApplicationServices
import CoreGraphics

/// System prompts are explicit onboarding actions, never a side effect of launching the helper.
@MainActor
enum ScreenPermissions {
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Codync Screen"
    }
    static var captureGranted: Bool { CGPreflightScreenCaptureAccess() }
    static var inputGranted: Bool { AXIsProcessTrusted() }

    static func request(_ permission: String) throws {
        switch permission {
        case "capture":
            if !captureGranted { _ = CGRequestScreenCaptureAccess() }
        case "input":
            if !inputGranted {
                // The C global for this option is not available under Swift 6 concurrency.
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
        default:
            throw HelperError("Unknown computer access permission.")
        }
    }

    /// The same signed executable in a fresh process can see a grant made after launch.
    static func probeCaptureGrant() async -> Bool {
        guard let executableURL = Bundle.main.executableURL else { return false }
        let probe = Process()
        probe.executableURL = executableURL
        probe.arguments = ["--probe-capture"]
        return await withCheckedContinuation { continuation in
            probe.terminationHandler = { process in
                continuation.resume(returning: process.terminationReason == .exit && process.terminationStatus == 0)
            }
            do { try probe.run() } catch { continuation.resume(returning: false) }
        }
    }
}
