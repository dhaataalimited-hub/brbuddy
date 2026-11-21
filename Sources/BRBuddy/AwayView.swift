import BRBuddyCore
import SwiftUI

/// What each away window shows: the companion, the tagline, how long you've been away, and (on the main display,
/// once someone touches the Mac) the unlock panel.
struct AwayView: View {
    let controller: AwayController
    let isPrimary: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.06, blue: 0.12), Color(red: 0.13, green: 0.09, blue: 0.16)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: showsMirror ? 18 : 28) {
                companion
                    .frame(width: showsMirror ? 170 : 260, height: showsMirror ? 156 : 240)

                Text("BRB — my agent's got this.")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let headline = agentSummary.headline {
                    Text(headline)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(agentSummary.needsAttention ? Color.orange : Color.white.opacity(0.8))
                }

                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text("Away \(awayFor)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                if showsMirror, let snapshot = controller.mirror?.snapshot {
                    TerminalMirrorView(snapshot: snapshot)
                        .frame(maxWidth: 980, maxHeight: 420)
                }

                footer
                    .frame(minHeight: showsMirror ? 150 : 180, alignment: .top)
            }
            .padding(40)
        }
        .overlay(alignment: .topTrailing) {
            if let status = batteryStatus {
                BatteryBadge(status: status, reaction: batteryReaction)
                    .padding(36)
            }
        }
    }

    private var batteryStatus: BatteryStatus? { controller.showsBattery ? controller.battery?.status : nil }

    private var batteryReaction: BatteryReaction {
        batteryStatus == nil ? .none : controller.battery?.reaction ?? .none
    }

    @ViewBuilder private var footer: some View {
        switch controller.phase {
        case .resting:
            Text("Press any key to unlock")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        case .unlocking:
            if isPrimary {
                UnlockPanel(controller: controller)
            } else {
                Text("Unlock on your main display")
                    .foregroundStyle(.white.opacity(0.5))
            }
        case .lockingForReal(let reason):
            Text(reason == .tooManyFailedAttempts ? "Too many tries. Locking the Mac." : "Been a while. Locking the Mac.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
        }
    }

    private var agentSummary: AgentTracker.Summary { controller.agents?.summary ?? .none }

    private var showsMirror: Bool { controller.mirror?.snapshot != nil }

    @ViewBuilder private var companion: some View {
        if let library = controller.companions {
            CompanionView(library: library, mood: mood, agent: controller.agents?.relevantAgent, battery: batteryReaction,
                          still: batteryStatus.map { !$0.isPluggedIn } ?? false,
                          canBoop: true, boopSounds: controller.boopSounds)
        }
    }

    private var mood: CompanionMood {
        var locking = false
        if case .lockingForReal = controller.phase { locking = true }
        return CompanionMood.current(isUnlocking: controller.phase == .unlocking, recentFailure: controller.recentFailure,
                                     lockingForReal: locking, agent: agentSummary, battery: batteryReaction)
    }

    private var awayFor: String {
        let minutes = Int(Date().timeIntervalSince(controller.awaySince) / 60)
        switch minutes {
        case 0: return "just now"
        case 1: return "for 1 minute"
        default: return "for \(minutes) minutes"
        }
    }
}
