import AppKit
import BRBuddyCore
import KeyboardShortcuts
import SwiftUI

/// What the menu bar item shows when clicked.
struct MenuContent: View {
    let state: AppState
    let updates: UpdateController
    let tour: TourController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle("Keep Mac awake", isOn: Binding(
            get: { state.manualKeepAwake },
            set: { state.setKeepingAwake($0) }
        ))
        if state.isKeepingAwakeForAgent && !state.manualKeepAwake {
            Text("Kept awake while your agent works")
        }

        Button("BRB now") { state.startAway() }
            .globalKeyboardShortcut(.brbNow)

        if state.isKeepingAwake && state.settings.autoStartEnabled {
            Text("BRB starts after \(state.settings.idleMinutes) min away")
        }
        if state.proximity.settings.isActive {
            Text("Walk-away: \(state.proximity.statusText)")
        }

        Divider()

        agentSection

        Divider()

        Button("Settings…") { showSettings() }
            .keyboardShortcut(",")

        Button("Show tour again") { tour.show() }

        if updates.isAvailable {
            Button("Check for Updates…") { updates.checkForUpdates() }
        }

        Button("Quit BRBuddy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var agentSection: some View {
        let sessions = state.agents.tracker.orderedSessions
        if sessions.isEmpty {
            if state.agents.hooksInstalled.isEmpty {
                Text("No agents set up yet")
                Button("Set up agents…") { showSettings() }
            } else {
                Text("No agents active")
            }
        } else {
            Text("Agents")
            ForEach(sessions.prefix(6)) { session in
                let title = "\(icon(session.activity)) \(session.agent.displayName)\(session.projectName.map { " · \($0)" } ?? "") — \(label(session.activity))"
                if TerminalFocuser.hostApp(of: session) != nil {
                    // Clicking jumps to the window (and tab, in Terminal and iTerm2) the agent runs in.
                    Button(title) { TerminalFocuser.focus(session) }
                } else {
                    Text(title)
                }
            }
        }
    }

    /// Opens Settings in front. BRBuddy has no Dock icon, so without activating it the window opens behind others.
    private func showSettings() {
        NSApp.activate()
        openSettings()
    }

    private func icon(_ activity: AgentActivity) -> String {
        switch activity {
        case .working: "⚙︎"
        case .waiting: "✋"
        case .finished: "✓"
        case .started, .ended: "·"
        }
    }

    private func label(_ activity: AgentActivity) -> String {
        switch activity {
        case .working: "working"
        case .waiting: "needs you"
        case .finished: "done"
        case .started: "ready"
        case .ended: "closed"
        }
    }
}
