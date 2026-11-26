import AppKit
import BRBuddyCore
import KeyboardShortcuts
import SwiftUI

/// The companion hanging on a string under the menu bar icon, swaying, with a speech bubble. Clicking it opens the
/// tour. Drawn over any companion, so every pack can hang.
struct HangingBuddyView: View {
    let tour: TourController
    @State private var hovering = false
    @State private var climbed = false

    private let stringLength: CGFloat = 46

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let angle = sin(t * 1.7) * (hovering ? 9 : 4)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: stringLength)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                    CompanionView(library: tour.state.companions, mood: .greeting,
                                  agent: tour.state.agents.relevantAgent)
                        .frame(width: 104, height: 96)
                        .padding(.top, -28)  // the critter is drawn inset in its frame; the string reaches its head
                        .allowsHitTesting(false)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                }
                .rotationEffect(.degrees(angle), anchor: .top)
            }
            .frame(height: stringLength + 70, alignment: .top)
            .offset(y: climbed ? -(stringLength + 90) : 0)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture { if !tour.isTouring && !tour.isLeaving { tour.startTour() } }
            .help("Click for a quick tour")

            if let bubble = tour.bubble, !climbed {
                SpeechBubble(text: bubble, canDismiss: !tour.isLeaving) { tour.finish() }
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .frame(width: TourController.buddySize.width, height: TourController.buddySize.height, alignment: .top)
        .onChange(of: tour.isLeaving) { _, leaving in
            guard leaving else { climbed = false; return }
            Task {
                try? await Task.sleep(for: .seconds(0.7))
                withAnimation(.easeIn(duration: 0.8)) { climbed = true }
            }
        }
    }
}

private struct SpeechBubble: View {
    let text: String
    let canDismiss: Bool
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.16, green: 0.08, blue: 0.13))
                .fixedSize(horizontal: false, vertical: true)
            if canDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                // A fixed colour: the bubble is always light, so .secondary would vanish in dark mode.
                .foregroundStyle(Color(red: 0.16, green: 0.08, blue: 0.13).opacity(0.6))
                .help("Not now (Show tour again is in the menu)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 1, green: 0.93, blue: 0.88)))
        .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        .frame(maxWidth: 210)
    }
}

/// The tour panel: four short steps (connect an agent, try BRB, pick a companion, extras) and a closing screen.
struct TourView: View {
    @Bindable var tour: TourController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tour.step.counter.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.93, green: 0.45, blue: 0.52))
            Text(tour.step.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 18)
        .frame(width: TourController.tourSize.width, height: TourController.tourSize.height, alignment: .topLeading)
    }

    @ViewBuilder private var content: some View {
        switch tour.step {
        case .agents: AgentsStep(monitor: tour.state.agents)
        case .tryBRB: tryStep
        case .companion: companionStep
        case .extras: extrasStep
        }
    }

    private var footer: some View {
        HStack {
            if !tour.step.isLast {
                Button("Skip tour") { tour.finish() }
                    .buttonStyle(.link)
            }
            Spacer()
            if tour.step != .agents {
                Button("Back") { tour.go(to: tour.step.previous) }
            }
            if tour.step.isLast {
                // Ending without trying BRB; Try BRB now (in the step) is the main way out.
                Button("Finish") { tour.finish() }
            } else {
                Button("Next") { tour.go(to: tour.step.next) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: Steps

    private var tryStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BRB covers your screen with your companion while your agent works, and keeps your Mac awake. To come back, use Touch ID or your password.")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "pawprint.fill")
                Text("I'm the paw in your menu bar. Start BRB from there any time\(shortcutText); while your Mac is kept awake it also starts by itself after \(tour.state.settings.idleMinutes) minutes away.")
            }
            .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Try BRB now") { tour.tryBRB() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                Text("This ends the tour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var shortcutText: String {
        KeyboardShortcuts.getShortcut(for: .brbNow).map { " or with \($0.description)" } ?? ""
    }

    private var companionStep: some View {
        CompanionStep(library: tour.state.companions, agent: tour.state.agents.relevantAgent) {
            tour.windows.showStudio()
        }
    }

    private var extrasStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            LaunchAtLoginToggle(state: tour.state, label: "Open BRBuddy when I log in")
            Toggle("Keep my Mac awake while an agent works", isOn: Binding(
                get: { tour.state.settings.keepAwakeForAgents },
                set: { tour.state.settings.keepAwakeForAgents = $0 }))
            VStack(alignment: .leading, spacing: 4) {
                Text("Walk-away lock").fontWeight(.semibold)
                Text("Start BRB (or lock your Mac) when your iPhone or Apple Watch leaves with you. Set it up in Settings → Walk-away.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Set up walk-away…") { tour.windows.showSettings(.walkAway) }
                .controlSize(.small)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Step 1: the agents found on this Mac, each with a Connect button (the same hook setup as Settings → Agents).
private struct AgentsStep: View {
    let monitor: AgentMonitor

    var body: some View {
        let found = AgentKind.allCases.filter { monitor.isPresent($0) || monitor.hooksInstalled.contains($0) }
        VStack(alignment: .leading, spacing: 10) {
            Text("BRBuddy listens to your coding agent, so your companion can show when it's working, done, or needs you. Connecting adds a small hook to the agent's settings; you can remove it any time in Settings → Agents.")
                .fixedSize(horizontal: false, vertical: true)
            if found.isEmpty {
                Text("No agents found on this Mac yet. When you install one (Claude Code, Codex, Gemini CLI…), connect it in Settings → Agents.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(found) { agent in row(agent) }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }

    private func row(_ agent: AgentKind) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.displayName).fontWeight(.medium)
                if let error = monitor.setupErrors[agent] {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            if monitor.hooksInstalled.contains(agent) {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Connect") { monitor.setUpHooks(for: agent) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

/// Step 3: a live preview and the same companion choice as Settings → Companion.
private struct CompanionStep: View {
    @Bindable var library: CompanionLibrary
    let agent: AgentKind?
    let openStudio: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { choice; more }
    }

    private var choice: some View {
        HStack(alignment: .top, spacing: 14) {
            CompanionView(library: library, mood: .greeting, agent: agent, canBoop: true)
                .frame(width: 92, height: 84)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.1, green: 0.08, blue: 0.14)))
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $library.choice) {
                    Text("Match my agent").tag(CompanionCatalog.Choice.matchAgent)
                    Text("Shuffle (a new one each BRB)").tag(CompanionCatalog.Choice.shuffle)
                    Divider()
                    ForEach(CompanionCatalog.builtIns) { critter in
                        Text(critter.name).tag(CompanionCatalog.Choice.builtIn(critter.id))
                    }
                    if !library.packs.isEmpty {
                        Divider()
                        ForEach(library.packs) { pack in
                            Text(pack.displayName).tag(CompanionCatalog.Choice.pack(pack.id))
                        }
                    }
                }
                .labelsHidden()
                Text("Click it to say hi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var more: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Or make your own in Companion Studio, or download one people have made.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Companion Studio…", action: openStudio)
                Link("Browse the gallery", destination: URL(string: "https://brbuddy.app/gallery/")!)
            }
            .controlSize(.small)
        }
        .padding(.top, 6)
    }
}
