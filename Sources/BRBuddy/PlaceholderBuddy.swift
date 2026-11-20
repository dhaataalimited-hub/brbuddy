import SwiftUI

/// A stand-in companion until companion packs arrive (Phase 3): an original round critter that breathes and snoozes
/// while you're away and opens its eyes when someone touches the Mac. Drawn in code, no art assets.
struct PlaceholderBuddy: View {
    var isAwake: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breath = 1 + 0.035 * sin(t * 1.6)
            let bob = isAwake ? 4 * sin(t * 3) : 0

            ZStack {
                // Ears
                HStack(spacing: 92) {
                    Circle().fill(earColor).frame(width: 46)
                    Circle().fill(earColor).frame(width: 46)
                }
                .offset(y: -66)

                // Body
                Ellipse()
                    .fill(LinearGradient(colors: [bodyColor, bodyColor.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 190, height: 160)
                    .scaleEffect(x: 1 / breath, y: breath, anchor: .bottom)

                // Face
                VStack(spacing: 14) {
                    HStack(spacing: 44) { eye; eye }
                    HStack(spacing: 92) { blush; blush }
                        .offset(y: -12)
                    mouth
                        .offset(y: -22)
                }
                .offset(y: 4)

                if !isAwake {
                    Text("z z z")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35 + 0.3 * sin(t * 1.2)))
                        .offset(x: 110, y: -80 - 6 * sin(t * 1.2))
                }
            }
            .offset(y: bob)
        }
        .animation(.spring(duration: 0.35), value: isAwake)
    }

    private var bodyColor: Color { Color(red: 0.98, green: 0.62, blue: 0.42) }
    private var earColor: Color { Color(red: 0.88, green: 0.52, blue: 0.36) }

    private var eye: some View {
        Capsule()
            .fill(Color(red: 0.16, green: 0.1, blue: 0.14))
            .frame(width: isAwake ? 18 : 24, height: isAwake ? 24 : 4)
    }

    private var blush: some View {
        Ellipse().fill(Color.pink.opacity(0.45)).frame(width: 22, height: 12)
    }

    private var mouth: some View {
        Capsule()
            .fill(Color(red: 0.16, green: 0.1, blue: 0.14))
            .frame(width: isAwake ? 16 : 10, height: isAwake ? 8 : 4)
    }
}
