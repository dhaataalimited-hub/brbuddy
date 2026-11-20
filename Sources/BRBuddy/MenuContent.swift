import AppKit
import KeyboardShortcuts
import SwiftUI

/// What the menu bar item shows when clicked.
struct MenuContent: View {
    let state: AppState

    var body: some View {
        Toggle("Keep Mac awake", isOn: Binding(
            get: { state.isKeepingAwake },
            set: { state.setKeepingAwake($0) }
        ))

        Button("BRB now") { state.startAway() }
            .globalKeyboardShortcut(.brbNow)

        if state.isKeepingAwake && state.settings.autoStartEnabled {
            Text("BRB starts after \(state.settings.idleMinutes) min away")
        }

        Divider()

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")

        Button("Quit BRBuddy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
