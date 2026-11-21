import BRBuddyCore
import SwiftUI

/// How a built-in companion looks. Each one is original and drawn in code; none uses an agent's logo or mascot.
struct CritterDesign {
    enum Body { case round, pebble, hex, cloud, spiky }
    enum Ears { case none, round, pointy }
    enum Accent { case none, sprout, starFreckles, wisps, snaggleTooth }

    var body: Body
    var top: Color
    var bottom: Color
    var ears: Ears
    var earColor: Color
    var accent: Accent
    var accentColor: Color
    var ink = Color(red: 0.14, green: 0.09, blue: 0.13)
    var blush = true
    /// Gremlin's left eye is bigger.
    var lopsided = false
    /// Drift hovers higher off the ground.
    var floats = false

    static func design(for id: String) -> CritterDesign {
        switch id {
        case "pebble":
            CritterDesign(body: .pebble, top: Color(white: 0.93), bottom: Color(white: 0.74), ears: .none,
                          earColor: .clear, accent: .sprout, accentColor: Color(red: 0.36, green: 0.72, blue: 0.42),
                          blush: false)
        case "prism":
            CritterDesign(body: .hex, top: Color(red: 0.36, green: 0.86, blue: 0.86), bottom: Color(red: 0.42, green: 0.36, blue: 0.86),
                          ears: .pointy, earColor: Color(red: 0.32, green: 0.6, blue: 0.86), accent: .none, accentColor: .clear)
        case "comet":
            CritterDesign(body: .round, top: Color(red: 0.25, green: 0.36, blue: 0.86), bottom: Color(red: 0.13, green: 0.16, blue: 0.5),
                          ears: .round, earColor: Color(red: 0.2, green: 0.26, blue: 0.7), accent: .starFreckles,
                          accentColor: Color(red: 1, green: 0.88, blue: 0.45), ink: Color(white: 0.98), blush: false)
        case "drift":
            CritterDesign(body: .cloud, top: Color(red: 0.97, green: 0.95, blue: 1), bottom: Color(red: 0.8, green: 0.76, blue: 0.95),
                          ears: .none, earColor: .clear, accent: .wisps, accentColor: Color(red: 0.8, green: 0.76, blue: 0.95),
                          floats: true)
        case "gremlin":
            CritterDesign(body: .spiky, top: Color(red: 0.66, green: 0.9, blue: 0.3), bottom: Color(red: 0.36, green: 0.62, blue: 0.2),
                          ears: .pointy, earColor: Color(red: 0.42, green: 0.7, blue: 0.22), accent: .snaggleTooth,
                          accentColor: .white, blush: false, lopsided: true)
        default:  // ember
            CritterDesign(body: .round, top: Color(red: 0.99, green: 0.66, blue: 0.46), bottom: Color(red: 0.86, green: 0.48, blue: 0.34),
                          ears: .round, earColor: Color(red: 0.88, green: 0.52, blue: 0.36), accent: .none, accentColor: .clear)
        }
    }
}

/// A built-in companion, animated for its mood. Lays out in a 240 × 220 box and scales to fit.
struct CritterView: View {
    let design: CritterDesign
    let mood: CompanionMood
    /// Battery reactions change how it moves: slow motion in Low Power Mode, drooping when low, glowing on the
    /// charger.
    var battery: BatteryReaction = .none
    /// Hide its own speech bubble (while the battery has something to say).
    var quiet = false
    /// On battery: the body holds still to save power, and only the face moves (glancing, blinking).
    var still = false

    /// Everything is drawn in this design space, then scaled to fit whatever frame the view is given.
    private static let canvas = CGSize(width: 300, height: 260)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.canvas.width, geometry.size.height / Self.canvas.height)
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate * timeScale
                ZStack {
                    critter(t)
                        .scaleEffect(x: 1 / droop, y: droop, anchor: .bottom)
                        .shadow(color: .yellow.opacity(glow(t)), radius: 22)
                        .offset(x: still ? 0 : motionX(t), y: still ? liftOnly : motionY(t))
                        .rotationEffect(.degrees(still ? 0 : mood == .greeting ? 6 * sin(t * 2.5) : lean(t)), anchor: .bottom)
                    if !quiet { bubble(t) }
                }
                .frame(width: Self.canvas.width, height: Self.canvas.height)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .aspectRatio(Self.canvas.width / Self.canvas.height, contentMode: .fit)
    }

    // MARK: Motion

    /// Low Power Mode plays everything in slow motion; a low battery makes it sluggish.
    private var timeScale: Double {
        switch battery {
        case .lowPower: 0.4
        case .low, .critical: 0.7
        default: 1
        }
    }

    /// Squashed down when the battery is low.
    private var droop: Double {
        switch battery {
        case .low: 0.94
        case .critical: 0.88
        default: 1
        }
    }

    /// A warm glow while charging.
    private func glow(_ t: Double) -> Double {
        switch battery {
        case .pluggedIn: 0.8
        case .charging: 0.25 + 0.15 * sin(t * 1.5)
        default: 0
        }
    }

    /// Wobbles when critical, as if about to tip over.
    private func lean(_ t: Double) -> Double { battery == .critical ? 4 * sin(t * 2.2) : 0 }

    private func motionY(_ t: Double) -> Double {
        let lift = design.floats ? -10 + 5 * sin(t * 1.3) : 0
        switch mood {
        case .working: return lift - abs(3 * sin(t * 9))
        case .waiting: return lift - abs(10 * sin(t * 4))
        case .finished: return lift - max(0, 18 * sin(t * 3.2))
        default: return lift
        }
    }

    private func motionX(_ t: Double) -> Double { mood == .oops ? 6 * sin(t * 30) * max(0, sin(t * 2)) : 0 }

    private func breath(_ t: Double) -> Double { still ? 1 : 1 + (mood == .resting ? 0.035 : 0.015) * sin(t * 1.6) }

    /// Drift still hovers when holding still, just without bobbing.
    private var liftOnly: Double { design.floats ? -10 : 0 }

    /// Where the eyes look while holding still: a slow glance left and right, so the face stays alive.
    private func glance(_ t: Double) -> Double { still ? 5 * sin(t * 0.9) : 0 }

    // MARK: Body

    private func critter(_ t: Double) -> some View {
        let fill = LinearGradient(colors: [design.top, design.bottom], startPoint: .top, endPoint: .bottom)
        return ZStack {
            ears
            bodyShape(fill)
                .frame(width: 190, height: 160)
                .scaleEffect(x: 1 / breath(t), y: breath(t), anchor: .bottom)
            accent(t)
            face(t).offset(y: 6)
        }
        .offset(y: 20)
    }

    @ViewBuilder private func bodyShape(_ fill: LinearGradient) -> some View {
        switch design.body {
        case .round: Ellipse().fill(fill)
        case .pebble: RoundedRectangle(cornerRadius: 70, style: .continuous).fill(fill)
        case .hex: SoftPolygon(points: 6, inner: 1, rotation: .pi / 6, roundness: 0.3).fill(fill)
        case .cloud: CloudShape().fill(fill)
        case .spiky: SoftPolygon(points: 11, inner: 0.8, rotation: 0, roundness: 0.6).fill(fill)
        }
    }

    @ViewBuilder private var ears: some View {
        switch design.ears {
        case .none: EmptyView()
        case .round:
            HStack(spacing: 92) {
                Circle().fill(design.earColor).frame(width: 48)
                Circle().fill(design.earColor).frame(width: 48)
            }
            .offset(y: -50)
        case .pointy:
            HStack(spacing: 70) {
                Triangle().fill(design.earColor).frame(width: 44, height: 56).rotationEffect(.degrees(-14))
                Triangle().fill(design.earColor).frame(width: 44, height: 56).rotationEffect(.degrees(14))
            }
            .offset(y: -62)
        }
    }

    @ViewBuilder private func accent(_ t: Double) -> some View {
        switch design.accent {
        case .none, .snaggleTooth: EmptyView()
        case .sprout:
            ZStack {
                Capsule().fill(design.accentColor.opacity(0.8)).frame(width: 4, height: 26)
                Ellipse().fill(design.accentColor).frame(width: 26, height: 14).rotationEffect(.degrees(-30)).offset(x: 12, y: -10)
                Ellipse().fill(design.accentColor).frame(width: 22, height: 12).rotationEffect(.degrees(30)).offset(x: -10, y: -6)
            }
            .rotationEffect(.degrees(6 * sin(t * 1.4)), anchor: .bottom)
            .offset(y: -70)
        case .starFreckles:
            ForEach(0..<5, id: \.self) { i in
                let spots: [(Double, Double, Double)] = [(-60, -30, 14), (58, -40, 11), (-40, 40, 9), (64, 26, 12), (8, -58, 8)]
                SoftPolygon(points: 5, inner: 0.45, rotation: -.pi / 2)
                    .fill(design.accentColor.opacity(0.6 + 0.4 * sin(t * 2 + Double(i))))
                    .frame(width: spots[i].2 * 1.6, height: spots[i].2 * 1.6)
                    .offset(x: spots[i].0, y: spots[i].1)
            }
        case .wisps:
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(design.accentColor.opacity(0.5))
                    .frame(width: 40 - Double(i) * 10, height: 6)
                    .offset(x: -30 + Double(i) * 30 + 6 * sin(t * 2 + Double(i)), y: 98 + Double(i % 2) * 8)
            }
        }
    }

    // MARK: Face

    private func face(_ t: Double) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 40) {
                eye(t, scale: design.lopsided ? 1.3 : 1)
                eye(t, scale: 1)
            }
            if design.blush {
                HStack(spacing: 96) {
                    Ellipse().fill(Color.pink.opacity(0.45)).frame(width: 22, height: 12)
                    Ellipse().fill(Color.pink.opacity(0.45)).frame(width: 22, height: 12)
                }
                .padding(.top, -8)
            }
            mouth(t)
        }
    }

    @ViewBuilder private func eye(_ t: Double, scale: Double) -> some View {
        let blink = mood != .resting && (t.truncatingRemainder(dividingBy: still ? 3 : 4) < 0.12)
        Group {
            switch mood {
            case .resting:
                Capsule().fill(design.ink).frame(width: 24, height: 4)
            case .finished:
                Arc(up: true).stroke(design.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 22, height: 12)
            case .oops:
                ZStack {
                    Capsule().fill(design.ink).frame(width: 22, height: 4).rotationEffect(.degrees(45))
                    Capsule().fill(design.ink).frame(width: 22, height: 4).rotationEffect(.degrees(-45))
                }
            case .waiting:
                Ellipse().fill(design.ink).frame(width: 22, height: blink ? 3 : 28)
            case .working:
                Ellipse().fill(design.ink).frame(width: 16, height: blink ? 3 : 18).offset(y: 4)
            case .greeting:
                Ellipse().fill(design.ink).frame(width: 18, height: blink ? 3 : 24)
            }
        }
        .scaleEffect(scale)
        .offset(x: [.waiting, .working, .greeting].contains(mood) ? glance(t) : 0)
        .frame(width: 30, height: 30)
    }

    @ViewBuilder private func mouth(_ t: Double) -> some View {
        ZStack {
            switch mood {
            case .resting, .working:
                // Holding still, a resting critter's mouth breathes instead of its body.
                Capsule().fill(design.ink)
                    .frame(width: mood == .working ? 14 : 10 + (still ? 4 * max(0, sin(t * 1.6)) : 0), height: 4)
            case .waiting:
                Ellipse().fill(design.ink).frame(width: 12, height: 14)
            case .finished, .greeting:
                Arc(up: false).stroke(design.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 26, height: 12)
            case .oops:
                Wave().stroke(design.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 28, height: 8)
            }
            if design.accent == .snaggleTooth && mood != .resting {
                Triangle().fill(design.accentColor).frame(width: 8, height: 9).rotationEffect(.degrees(180)).offset(x: 6, y: 7)
            }
        }
        .frame(height: 16)
    }

    // MARK: Speech bubble and sparkles

    @ViewBuilder private func bubble(_ t: Double) -> some View {
        switch mood {
        case .resting:
            Text("z z z")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35 + 0.3 * sin(t * 1.2)))
                .offset(x: 104, y: -76 - 6 * sin(t * 1.2))
        case .working:
            BubbleLabel(text: String(repeating: "•", count: 1 + Int(t * 3) % 3)).offset(x: 100, y: -72)
        case .waiting:
            BubbleLabel(text: "!", tint: .orange).offset(x: 100, y: -78).scaleEffect(1 + 0.08 * sin(t * 6))
        case .greeting:
            BubbleLabel(text: "hi!").offset(x: 100, y: -72)
        case .finished:
            ForEach(0..<4, id: \.self) { i in
                let angle = Double(i) * .pi / 2 + t
                SoftPolygon(points: 5, inner: 0.45, rotation: -.pi / 2)
                    .fill(Color.yellow.opacity(0.85))
                    .frame(width: 16, height: 16)
                    .offset(x: 120 * cos(angle), y: -10 + 70 * sin(angle))
            }
        case .oops:
            BubbleLabel(text: "?!", tint: .orange).offset(x: 100, y: -72)
        }
    }
}

struct BubbleLabel: View {
    let text: String
    var tint: Color = .white

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(red: 0.14, green: 0.09, blue: 0.13))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint))
    }
}

// MARK: Shapes

/// A star or regular polygon with rounded points. `inner` 1 gives a polygon; less gives spikes.
struct SoftPolygon: Shape {
    var points: Int
    var inner: Double
    var rotation: Double
    /// 0 = sharp corners, 1 = as round as the edges allow.
    var roundness: Double = 0.5

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        let steps = inner < 1 ? points * 2 : points
        let corners = (0..<steps).map { i -> CGPoint in
            let radius = (inner < 1 && i % 2 == 1) ? inner : 1
            let angle = rotation + Double(i) * 2 * .pi / Double(steps)
            return CGPoint(x: center.x + rx * radius * cos(angle), y: center.y + ry * radius * sin(angle))
        }
        // Rounded corners: straight edges, with each corner cut by a curve `roundness` of the way along its edges.
        func toward(_ a: CGPoint, _ b: CGPoint, _ f: Double) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f) }
        let f = roundness / 2
        var path = Path()
        path.move(to: toward(corners[0], corners[1], f))
        for i in 1...steps {
            let corner = corners[i % steps]
            path.addLine(to: toward(corner, corners[i - 1], f))
            path.addQuadCurve(to: toward(corner, corners[(i + 1) % steps], f), control: corner)
        }
        path.closeSubpath()
        return path
    }
}

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let puffs: [(Double, Double, Double)] = [(0.5, 0.55, 0.42), (0.25, 0.6, 0.27), (0.75, 0.6, 0.27), (0.36, 0.36, 0.25), (0.64, 0.34, 0.27)]
        for (x, y, r) in puffs {
            path.addEllipse(in: CGRect(x: rect.minX + w * (x - r), y: rect.minY + h * (y - r * w / h),
                                       width: w * 2 * r, height: w * 2 * r))
        }
        return path
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// A smile (up: false) or a happy closed eye (up: true).
struct Arc: Shape {
    var up: Bool
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: up ? rect.maxY : rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: up ? rect.maxY : rect.minY),
                           control: CGPoint(x: rect.midX, y: up ? rect.minY - rect.height : rect.maxY + rect.height))
        }
    }
}

struct Wave: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control1: CGPoint(x: rect.minX + rect.width / 3, y: rect.minY - rect.height),
                       control2: CGPoint(x: rect.minX + 2 * rect.width / 3, y: rect.maxY + rect.height))
        }
    }
}
