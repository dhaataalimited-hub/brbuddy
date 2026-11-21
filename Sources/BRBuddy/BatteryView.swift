import BRBuddyCore
import SwiftUI

/// The battery on the away screen: a glass pill with a liquid-filled battery, the percentage and what's going on.
/// The liquid sloshes, bubbles while charging, pulses red when critical, and bursts with sparks when plugged in.
struct BatteryBadge: View {
    let status: BatteryStatus
    let reaction: BatteryReaction

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let tint = Self.tint(status)
            HStack(spacing: 16) {
                BatteryGlyph(status: status, tint: tint, t: t)
                    .frame(width: 78, height: 36)
                    .offset(x: reaction == .critical ? 2 * sin(t * 40) * max(0, sin(t * 1.5)) : 0)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(status.percent)%")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .fixedSize()
                        .foregroundStyle(reaction == .critical ? tint : .white.opacity(0.55))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(tint.opacity(0.25 + glow(t) * 0.5), lineWidth: 1.5))
                    .shadow(color: tint.opacity(glow(t) * 0.7), radius: 24)
            }
            .overlay { if reaction == .pluggedIn { SparkBurst(t: t, color: tint) } }
            .scaleEffect(reaction == .pluggedIn ? 1 + 0.05 * max(0, sin(t * 7)) : 1)
        }
        .animation(.spring(duration: 0.5), value: status.percent)
    }

    /// How brightly the pill glows: a slow breath while charging, a fast pulse when critical.
    private func glow(_ t: Double) -> Double {
        switch reaction {
        case .critical: 0.6 + 0.4 * sin(t * 6)
        case .low: 0.25 + 0.15 * sin(t * 3)
        case .pluggedIn: 0.9
        case .charging: 0.3 + 0.2 * sin(t * 1.5)
        default: 0
        }
    }

    private var caption: String {
        let time = status.minutesRemaining.map(Self.duration)
        switch reaction {
        case .pluggedIn: return "Charger connected"
        case .unplugged: return "On battery now"
        case .full: return "Fully charged"
        case .critical: return time.map { "Plug in soon · \($0) left" } ?? "Plug in soon"
        case .low: return time.map { "Low battery · \($0) left" } ?? "Low battery"
        case .lowPower: return time.map { "Low Power Mode · \($0) left" } ?? "Low Power Mode"
        case .charging, .none:
            if status.isCharging { return time.map { "Charging · \($0) to full" } ?? "Charging" }
            if status.isPluggedIn { return "Plugged in · not charging" }
            return time.map { "\($0) left" } ?? "On battery"
        }
    }

    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }

    static func tint(_ status: BatteryStatus) -> Color {
        if status.isCritical { return Color(red: 1, green: 0.27, blue: 0.3) }
        if status.isLowPowerMode { return Color(red: 1, green: 0.82, blue: 0.2) }
        if status.isLow { return Color(red: 1, green: 0.58, blue: 0.2) }
        return Color(red: 0.3, green: 0.9, blue: 0.5)
    }
}

/// A battery outline filled with liquid up to the charge level, with a bolt when it's on the charger.
private struct BatteryGlyph: View {
    let status: BatteryStatus
    let tint: Color
    let t: Double

    var body: some View {
        GeometryReader { geometry in
            let nub: CGFloat = 5
            let body = CGSize(width: geometry.size.width - nub - 2, height: geometry.size.height)
            HStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                    Liquid(level: max(Double(status.percent) / 100, 0.04), phase: t * (status.isCharging ? 4 : 1.2),
                           amplitude: status.isCharging ? 2.5 : 1.2)
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                        .overlay { if status.isCharging { bubbles(in: body) } }
                        .padding(4)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.75), lineWidth: 2.5)
                    if status.isPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                            .scaleEffect(1 + 0.08 * sin(t * 3))
                    } else if status.isLowPowerMode {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                }
                .frame(width: body.width, height: body.height)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.75))
                    .frame(width: nub, height: body.height * 0.38)
            }
        }
    }

    /// Little bubbles rising through the liquid while charging.
    private func bubbles(in size: CGSize) -> some View {
        let filled = (size.width - 8) * CGFloat(status.percent) / 100
        return ZStack {
            ForEach(0..<5, id: \.self) { i in
                let speed = 0.5 + Double(i % 3) * 0.2
                let progress = (t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(.white.opacity(0.55 * (1 - progress)))
                    .frame(width: 3 + CGFloat(i % 2) * 2)
                    .position(x: filled * CGFloat(0.15 + 0.17 * Double(i)), y: (size.height - 8) * CGFloat(1 - progress))
            }
        }
    }
}

/// Liquid filling a battery from the left, with a gently moving wave at its edge.
private struct Liquid: Shape {
    var level: Double
    var phase: Double
    var amplitude: Double

    func path(in rect: CGRect) -> Path {
        let edge = rect.minX + rect.width * level
        return Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: edge, y: rect.minY))
            for step in 0...20 {
                let y = rect.minY + rect.height * Double(step) / 20
                let x = level >= 0.99 ? rect.maxX : edge + amplitude * sin(Double(step) / 20 * 2 * .pi * 1.3 + phase)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Bolts and sparks flying out from the middle, over and over, while the plugged-in flourish plays.
private struct SparkBurst: View {
    let t: Double
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let angle = Double(i) / 10 * 2 * .pi + 0.3
                let progress = (t * 0.9 + Double(i % 3) * 0.2).truncatingRemainder(dividingBy: 1)
                Image(systemName: i % 2 == 0 ? "bolt.fill" : "sparkle")
                    .font(.system(size: 12 + CGFloat(i % 3) * 3, weight: .bold))
                    .foregroundStyle(i % 2 == 0 ? Color.yellow : color)
                    .opacity(1 - progress)
                    .offset(x: cos(angle) * (60 + 70 * progress), y: sin(angle) * (30 + 40 * progress))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The companion's battery props, drawn over either kind of companion: a bolt while charging, a sweat drop when low,
/// a tortoise in Low Power Mode, sparks when plugged in, and its speech bubble. Laid out in the critter's 300 × 260
/// design space and scaled to fit.
struct BatteryFlair: View {
    let reaction: BatteryReaction
    /// Show the battery's speech bubble (off while the companion has something more important to say).
    let talks: Bool

    private static let canvas = CGSize(width: 300, height: 260)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.canvas.width, geometry.size.height / Self.canvas.height)
            TimelineView(.animation) { timeline in
                props(timeline.date.timeIntervalSinceReferenceDate)
                    .frame(width: Self.canvas.width, height: Self.canvas.height)
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func props(_ t: Double) -> some View {
        ZStack {
            switch reaction {
            case .charging, .full:
                Image(systemName: "bolt.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(reaction == .full ? Color.green : Color.yellow)
                    .shadow(color: .yellow.opacity(0.7), radius: 8)
                    .rotationEffect(.degrees(10 * sin(t * 2)))
                    .offset(x: -104, y: -70 + 6 * sin(t * 2.4))
            case .pluggedIn:
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) / 8 * 2 * .pi + t * 1.5
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow, radius: 6)
                        .offset(x: 128 * cos(angle), y: 10 + 92 * sin(angle))
                }
            case .low, .critical:
                SweatDrop()
                    .fill(LinearGradient(colors: [Color(red: 0.6, green: 0.85, blue: 1), Color(red: 0.3, green: 0.6, blue: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 16, height: 24)
                    .offset(x: 96, y: -12 + 26 * (t * (reaction == .critical ? 1.4 : 0.8)).truncatingRemainder(dividingBy: 1))
                    .opacity(1 - (t * (reaction == .critical ? 1.4 : 0.8)).truncatingRemainder(dividingBy: 1) * 0.8)
            case .lowPower:
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 0.45))
                    .offset(x: -118 + 10 * sin(t * 0.5), y: 104)
            case .none, .unplugged:
                EmptyView()
            }
            if talks, let text = reaction.bubble {
                let urgent = reaction == .critical
                BubbleLabel(text: text, tint: urgent ? Color(red: 1, green: 0.4, blue: 0.4)
                                                     : reaction == .pluggedIn ? .yellow : .white)
                    .scaleEffect(urgent ? 1 + 0.08 * sin(t * 7) : 1)
                    .offset(x: 100, y: -76)
            }
        }
    }
}

/// A teardrop, point up.
private struct SweatDrop: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.width / 2),
                           control: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.1))
            p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY - rect.width / 2), radius: rect.width / 2,
                     startAngle: .zero, endAngle: .degrees(180), clockwise: false)
            p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                           control: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.1))
        }
    }
}
