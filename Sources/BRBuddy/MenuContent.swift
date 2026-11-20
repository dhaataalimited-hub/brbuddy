import AppKit
import SwiftUI

/// What the menu bar item shows when clicked.
struct MenuContent: View {
    let state: AppState

    var body: some View {
        Toggle("Keep Mac awake", isOn: Binding(
            get: { state.isKeepingAwake },
            set: { state.setKeepingAwake($0) }
        ))

        Button("BRB (Away mode): coming soon") {}
            .disabled(true)

        Divider()

        Button("Quit BRBuddy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
