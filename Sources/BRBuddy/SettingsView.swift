import BRBuddyCore
import KeyboardShortcuts
import SwiftUI

/// The Settings window, in tabs so it fits small screens: General (when BRB starts and when it hands off to the real
/// lock screen, the shortcut, launch at login), Agents, Companion, Away screen (terminal mirror) and Walk-away.
struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView {
            tab { generalSections }
                .tabItem { Label("General", systemImage: "gearshape") }
            tab { agentsSection }
                .tabItem { Label("Agents", systemImage: "terminal") }
            tab { CompanionSection(library: state.companions, agent: state.agents.relevantAgent) }
                .tabItem { Label("Companion", systemImage: "pawprint") }
            tab { MirrorSection(mirror: state.mirror) }
                .tabItem { Label("Away Screen", systemImage: "display") }
            tab { WalkAwaySection(monitor: state.proximity) }
                .tabItem { Label("Walk-away", systemImage: "figure.walk") }
        }
        // A fixed size that fits a 13-inch screen; each tab scrolls if its content is taller.
        .frame(width: 540, height: 480)
        .onAppear { state.agents.refresh() }
    }

    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Form { content() }.formStyle(.grouped)
    }

    @ViewBuilder private var generalSections: some View {
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

    @ViewBuilder private var agentsSection: some View {
        Section("Agents") {
            Toggle("Keep the Mac awake while an agent is working or needs you", isOn: $state.settings.keepAwakeForAgents)
            ForEach(AgentKind.allCases) { agent in
                AgentRow(agent: agent, monitor: state.agents)
            }
            if !state.agents.runningDesktopApps.isEmpty {
                Text("Also open: \(state.agents.runningDesktopApps.joined(separator: ", ")). Desktop apps have no hooks, so BRBuddy can't see when they're working.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Set up adds BRBuddy's hook to that agent's own settings file (a backup is saved next to it). The hook only reports what the agent is doing; it can't change or block anything.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = state.agents.listenerError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

/// Choosing the away-screen companion, with a live preview and community pack import.
private struct CompanionSection: View {
    @Bindable var library: CompanionLibrary
    let agent: AgentKind?

    var body: some View {
        Section("Companion") {
            HStack(alignment: .top, spacing: 16) {
                CompanionView(library: library, mood: .greeting, agent: agent)
                    .frame(width: 96, height: 88)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.1, green: 0.08, blue: 0.14)))
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Companion", selection: $library.choice) {
                        Text("Match my agent").tag(CompanionCatalog.Choice.matchAgent)
                        Divider()
                        ForEach(CompanionCatalog.builtIns) { critter in
                            Text("\(critter.name) (\(critter.agent.displayName) vibe)").tag(CompanionCatalog.Choice.builtIn(critter.id))
                        }
                        if !library.packs.isEmpty {
                            Divider()
                            ForEach(library.packs) { pack in
                                Text(pack.displayName).tag(CompanionCatalog.Choice.pack(pack.id))
                            }
                        }
                    }
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Add companion pack…") { library.chooseAndImport() }
                Button("Show companions folder") { library.revealFolder() }
            }
            if let error = library.importError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            ForEach(library.problems, id: \.folder) { problem in
                Text("\(problem.folder): \(problem.reason)").font(.caption).foregroundStyle(.orange)
            }
            Text("Packs use the Codex pet format (pet.json + spritesheet), so pets made for Codex work here too.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { library.reload() }
    }

    private var caption: String {
        switch library.resolved(for: agent) {
        case .builtIn(let critter):
            return critter.blurb + "."
        case .pack(let id):
            guard let pack = library.pack(id: id) else { return "" }
            let by = pack.author.map { " by \($0)" } ?? ""
            let license = pack.license.map { " · \($0)" } ?? " · license not stated"
            return "Community pack\(by)\(license)"
        }
    }
}

/// Choosing what the away screen mirrors, with a live preview while Settings is open.
private struct MirrorSection: View {
    @Bindable var mirror: TerminalMirror
    @State private var trusted = AccessibilityTerminalReader.isTrusted

    var body: some View {
        Section("Terminal on the away screen") {
            Picker("Show", selection: $mirror.mode) {
                ForEach(TerminalMirrorMode.allCases) { Text($0.title).tag($0) }
            }
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
            if mirror.isEnabled {
                if let snapshot = mirror.snapshot {
                    TerminalMirrorView(snapshot: snapshot, fontSize: 10)
                        .frame(height: 150)
                } else if let status = mirror.status {
                    Text(status).font(.caption).foregroundStyle(.orange)
                }
                if (mirror.mode == .automatic || mirror.mode == .terminalWindow) && !trusted {
                    Button("Allow BRBuddy to read terminal windows…") {
                        AccessibilityTerminalReader.requestTrust()
                    }
                }
                Text("Anyone at your Mac can read what's shown. It's view-only: nothing typed on the away screen reaches the terminal.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear { mirror.retain() }
        .onDisappear { mirror.release() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = AccessibilityTerminalReader.isTrusted
        }
    }

    private var explanation: String {
        switch mirror.mode {
        case .off: "The away screen shows only the companion."
        case .automatic: "Uses tmux if your agent runs in it, then a Terminal, iTerm2 or Ghostty window, then the agent activity feed."
        case .tmux: "Shows the tmux pane your agent runs in, in colour.\(mirror.tmuxInstalled ? "" : " tmux isn't installed (brew install tmux).")"
        case .terminalWindow: "Shows the text of a Terminal, iTerm2 or Ghostty window. Needs Accessibility permission."
        case .activityFeed: "Shows what your hooked-up agents are doing (tools and commands), with no extra permissions. Never your prompts."
        }
    }
}

/// Walk-away lock: pick a phone or watch, how far is "away", and what happens.
private struct WalkAwaySection: View {
    @Bindable var monitor: ProximityMonitor
    @State private var picking = false

    var body: some View {
        Section("Walk-away lock") {
            if !ProximityMonitor.isAvailable {
                Text("Build BRBuddy as an app (Tools/build-app.sh) to use Bluetooth.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Toggle("When my iPhone or Apple Watch walks away", isOn: $monitor.settings.enabled)
                    .disabled(monitor.settings.deviceID == nil)
                Picker("Then", selection: $monitor.settings.action) {
                    ForEach(ProximitySettings.Action.allCases) { Text($0.title).tag($0) }
                }
                Picker("Away means", selection: $monitor.settings.range) {
                    ForEach(ProximityTracker.Range.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text(monitor.settings.deviceName.map { "Device: \($0)" } ?? "No device chosen")
                    Spacer()
                    Button(picking ? "Done" : "Choose device…") {
                        picking.toggle()
                        monitor.setPickerOpen(picking)
                    }
                }
                if picking { devicePicker }
                Text(monitor.statusText)
                    .font(.caption)
                    .foregroundStyle(monitor.bluetoothState == .unauthorized || monitor.bluetoothState == .poweredOff ? .orange : .secondary)
                Text("Bluetooth signal is rough: it can't see through you, so test it a few times and adjust the range. Your phone needs Bluetooth on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            if picking { picking = false; monitor.setPickerOpen(false) }
        }
    }

    @ViewBuilder private var devicePicker: some View {
        Text("Hold your iPhone or Apple Watch right next to the Mac, unlocked: yours moves to the top and is marked Closest.")
            .font(.caption)
            .foregroundStyle(.secondary)
        if monitor.nearbyDevices.isEmpty {
            HStack {
                ProgressView().controlSize(.small)
                Text("Looking for nearby iPhones and Apple Watches…")
                    .font(.caption)
            }
        } else {
            ForEach(monitor.nearbyDevices.prefix(6)) { device in
                HStack {
                    Image(systemName: icon(device.kind))
                        .frame(width: 18)
                    Text(device.title)
                    if device.id == monitor.closestDeviceID {
                        Text("Closest")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    }
                    Spacer()
                    Text("\(Int(device.rssi.rounded())) dBm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    SignalBars(rssi: Int(device.rssi))
                    Button("Use") {
                        monitor.choose(device)
                        picking = false
                        monitor.setPickerOpen(false)
                    }
                }
            }
        }
    }

    private func icon(_ kind: AppleDeviceInfo.Kind?) -> String {
        switch kind {
        case .watch: "applewatch"
        case .iPhone: "iphone"
        default: "questionmark.circle"
        }
    }
}

private struct SignalBars: View {
    let rssi: Int

    var body: some View {
        let lit = rssi > -45 ? 4 : rssi > -60 ? 3 : rssi > -75 ? 2 : 1
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= lit ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(3 + bar * 3))
            }
        }
        .help("Signal \(rssi) dBm")
    }
}

/// One agent in Settings: whether it's on this Mac, whether hooks are set up, and the button to change that.
private struct AgentRow: View {
    let agent: AgentKind
    let monitor: AgentMonitor

    var body: some View {
        let installed = monitor.hooksInstalled.contains(agent)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                Text(status(installed: installed))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = monitor.setupErrors[agent] {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            if installed {
                Button("Remove") { monitor.removeHooks(for: agent) }
            } else {
                Button("Set up") { monitor.setUpHooks(for: agent) }
                    .disabled(!monitor.isPresent(agent))
            }
        }
    }

    private func status(installed: Bool) -> String {
        let running = monitor.runningAgents.contains(agent) ? " · running now" : ""
        if installed { return "Hooked up\(running)" }
        return monitor.isPresent(agent) ? "Not set up\(running)" : "Not found on this Mac"
    }
}
