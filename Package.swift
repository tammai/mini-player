// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mini-player",
    platforms: [.macOS("26.0")],
    targets: [
        // Pure logic: stream parsing, state merging, display state machine.
        .target(name: "MiniPlayerCore"),
        // AppKit shell: menu bar item, adapter subprocess, glass card window.
        .executableTarget(name: "MiniPlayer", dependencies: ["MiniPlayerCore"]),
        .testTarget(name: "MiniPlayerCoreTests", dependencies: ["MiniPlayerCore"]),
    ],
    swiftLanguageModes: [.v5]
)
