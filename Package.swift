// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BRBuddy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BRBuddy", targets: ["BRBuddy"]),
        .executable(name: "brbuddy-hook", targets: ["brbuddy-hook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
    ],
    targets: [
        // Pure logic and system wrappers, no UI. Everything testable lives here.
        .target(name: "BRBuddyCore"),
        // The menu bar app.
        .executableTarget(name: "BRBuddy", dependencies: ["BRBuddyCore", "KeyboardShortcuts", .product(name: "Sparkle", package: "Sparkle")]),
        // Run by agents' hooks: forwards one event to the app and exits. Never prints, always exits 0.
        .executableTarget(name: "brbuddy-hook", dependencies: ["BRBuddyCore"]),
        .testTarget(name: "BRBuddyTests", dependencies: ["BRBuddyCore"]),
    ]
)
