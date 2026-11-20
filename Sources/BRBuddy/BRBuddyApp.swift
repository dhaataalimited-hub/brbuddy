import AppKit
import SwiftUI

/// App entry point: a menu bar item only, no Dock icon or main window.
@main
struct BRBuddyApp: App {
    @State private var state = AppState()

    init() {
        // Also set by LSUIElement in the bundle's Info.plist; this covers `swift run`.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("BRBuddy", systemImage: state.isKeepingAwake ? "pawprint.fill" : "pawprint") {
            MenuContent(state: state)
        }
    }
}
