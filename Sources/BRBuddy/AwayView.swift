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

            VStack(spacing: 28) {
                PlaceholderBuddy(isAwake: controller.phase != .resting)
                    .frame(width: 220, height: 200)

                Text("BRB — my agent's got this.")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text("Away \(awayFor)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                footer
                    .frame(minHeight: 180, alignment: .top)
            }
            .padding(40)
        }
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

    private var awayFor: String {
        let minutes = Int(Date().timeIntervalSince(controller.awaySince) / 60)
        switch minutes {
        case 0: return "just now"
        case 1: return "for 1 minute"
        default: return "for \(minutes) minutes"
        }
    }
}
