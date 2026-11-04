// swift-tools-version: 5.9
import PackageDescription

// The DSH conversation client. Kept a separate module on purpose: the host app compiles with
// Swift 6 and complete concurrency checking, and this package's UI/transport code is written for
// Swift 5 (as agreed for the DSH integration), so it must not share the host's language mode.
let package = Package(
    name: "DSHKit",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "DSHKit", targets: ["DSHKit"]),
    ],
    targets: [
        .target(name: "DSHKit"),
    ]
)
