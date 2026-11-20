// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BRBuddy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BRBuddy", targets: ["BRBuddy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
    ],
    targets: [
        // Pure logic and system wrappers, no UI. Everything testable lives here.
        .target(name: "BRBuddyCore"),
        // The menu bar app.
        .executableTarget(name: "BRBuddy", dependencies: ["BRBuddyCore", "KeyboardShortcuts"]),
        .testTarget(name: "BRBuddyTests", dependencies: ["BRBuddyCore"]),
    ]
)
