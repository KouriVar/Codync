import Foundation
import Testing
@testable import CodyncKit
@testable import CodyncUI

// The Codync row on a computer's card (BotStore+HostUpdate). This build has no button that asks a
// computer to update itself, so the row only says what's due and how to get it on that machine.

@Test func theCodyncRowOffersANewerReleaseOrSaysItsCurrent() {
    let line = { (latest: String?, offer: HostUpdateOffer) in
        HostVersionLine.make(version: "2.28.0", latest: latest, mismatch: nil, offer: offer, host: "Mac", os: "macos")
    }
    #expect(line("2.28.0", .available(last: nil)) == HostVersionLine(version: "2.28.0", detail: ["Up to date"]))
    #expect(line("2.27.0", .available(last: nil)).detail == ["Up to date"])
    // A computer that doesn't know the latest release makes no claim.
    #expect(line(nil, .available(last: nil)) == HostVersionLine(version: "2.28.0", detail: []))
    // A newer release: said, with how to get it there (no accessory: this build can't ask it).
    #expect(line("2.29.0", .available(last: nil))
        == HostVersionLine(version: "2.28.0", detail: ["Version 2.29.0 is available.", "Update Codync on that computer."]))
    // Not from here either: it says how, on that computer.
    #expect(line("2.29.0", .unavailable)
        == HostVersionLine(version: "2.28.0", detail: ["Version 2.29.0 is available.", "Update Codync on that computer."]))
    // Updating: the row ends with a spinner.
    #expect(line("2.29.0", .updating)
        == HostVersionLine(version: "2.28.0", detail: ["Updating Codync on Mac. This takes a few minutes."], accessory: .updating))
}

@Test func aComputerTooOldOrAnUpdateThatDidntTakeIsAProblem() {
    let behind = VersionMismatch.updateHost(version: "2.20.0", minimum: "2.26.0")
    let old = HostVersionLine.make(version: "2.20.0", latest: nil, mismatch: behind, offer: .available(last: nil), host: "Mac", os: "linux")
    #expect(old == HostVersionLine(version: "2.20.0", detail: ["This app needs 2.26.0 or newer.", "Update Codync on that computer."],
                                   warns: true))
    let manual = HostVersionLine.make(version: "2.20.0", latest: "2.29.0", mismatch: behind, offer: .unavailable, host: "Mac", os: "linux")
    #expect(manual.detail == ["This app needs 2.26.0 or newer.", "Update Codync on that computer."] && manual.warns)
    let failed = HostVersionLine.make(version: "2.28.0", latest: "2.29.0", mismatch: nil,
                                      offer: .available(last: .failed("A bot is working on this computer.")), host: "Mac", os: "macos")
    #expect(failed == HostVersionLine(version: "2.28.0", detail: ["A bot is working on this computer."], warns: true))
    // Asked, but the computer never came back updated.
    let stalled = HostVersionLine.make(version: "2.28.0", latest: "2.29.0", mismatch: nil,
                                       offer: .available(last: .requested(at: .now)), host: "Mac", os: "macos")
    #expect(stalled == HostVersionLine(version: "2.28.0",
                                       detail: ["Mac didn't finish updating. Try again, or update Codync on that computer."],
                                       warns: true))
}
