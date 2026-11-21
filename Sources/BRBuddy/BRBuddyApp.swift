import AppKit
import SwiftUI

/// App entry point: a menu bar item, a Settings window and the Companion Studio window; no Dock icon or main window.
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
        Window("Companion Studio", id: CompanionStudioView.windowID) {
            CompanionStudioView(library: delegate.state.companions)
        }
        .windowResizability(.contentSize)
    }
}
