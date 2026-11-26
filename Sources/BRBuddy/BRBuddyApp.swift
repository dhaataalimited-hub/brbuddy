import AppKit
import SwiftUI

/// App entry point. The menu bar item and every window are AppKit-owned (`StatusItemController`, `AppWindows`), made
/// by `AppDelegate`; SwiftUI only supplies the app lifecycle. No Dock icon or main window.
@main
struct BRBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Also set by LSUIElement in the bundle's Info.plist; this covers `swift run`.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        // SwiftUI needs a scene. A menu bar extra that is never inserted shows nothing and, unlike an empty Settings
        // scene, never opens a window by itself. Its command sends ⌘, to BRBuddy's own Settings window.
        MenuBarExtra(isInserted: .constant(false)) { EmptyView() } label: { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { delegate.windows.showSettings() }
                        .keyboardShortcut(",")
                }
            }
    }
}
