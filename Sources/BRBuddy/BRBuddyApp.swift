import AppKit
import SwiftUI

/// App entry point: a menu bar item and a Settings window, no Dock icon or main window.
@main
struct BRBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Also set by LSUIElement in the bundle's Info.plist; this covers `swift run`.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("BRBuddy", systemImage: delegate.state.isKeepingAwake ? "pawprint.fill" : "pawprint") {
            MenuContent(state: delegate.state, updates: delegate.updates)
        }
        Settings {
            SettingsView(state: delegate.state)
        }
    }
}
