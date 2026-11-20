import BRBuddyCore
import KeyboardShortcuts
import SwiftUI

/// The Settings window: when BRB starts, when it hands off to the real lock screen, the shortcut, launch at login.
struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        Form {
            Section("Starting BRB") {
                Toggle("Start BRB on its own while keeping the Mac awake", isOn: $state.settings.autoStartEnabled)
                Stepper("After \(state.settings.idleMinutes) min with no keyboard or mouse",
                        value: $state.settings.idleMinutes, in: 1...120)
                    .disabled(!state.settings.autoStartEnabled)
                KeyboardShortcuts.Recorder("BRB now shortcut:", name: .brbNow)
            }

            Section("Locking for real") {
                Stepper("After \(state.settings.maxFailedAttempts) failed unlock tries",
                        value: $state.settings.maxFailedAttempts, in: 1...10)
                Picker("After being away for", selection: $state.settings.escalateAfterMinutes) {
                    Text("Never").tag(0)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("4 hours").tag(240)
                }
                Text("Hands off to the macOS lock screen. Your agent keeps running; only sleep stops it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Open BRBuddy at login", isOn: Binding(
                    get: { state.launchesAtLogin },
                    set: { state.setLaunchesAtLogin($0) }
                ))
                if let error = state.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }

            Section {
                Text("BRB is a deterrent, not a vault: holding the power button still restarts the Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
    }
}
