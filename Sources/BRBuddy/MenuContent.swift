import AppKit
import BRBuddyCore
import KeyboardShortcuts
import SwiftUI

/// What the menu bar item shows when clicked.
struct MenuContent: View {
    let state: AppState

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

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")

        Button("Quit BRBuddy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var agentSection: some View {
        let sessions = state.agents.tracker.orderedSessions
        if sessions.isEmpty {
            if state.agents.hooksInstalled.isEmpty {
                Text("No agents set up yet")
                SettingsLink { Text("Set up agents…") }
            } else {
                Text("No agents active")
            }
        } else {
            Text("Agents")
            ForEach(sessions.prefix(6)) { session in
                Text("\(icon(session.activity)) \(session.agent.displayName)\(session.projectName.map { " · \($0)" } ?? "") — \(label(session.activity))")
            }
        }
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
