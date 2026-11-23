#if DEBUG
import AppKit
import BRBuddyCore
import SwiftUI

/// Debug builds only: the 30-second promo film, drawn frame by frame with the real companion code. Writes PNG frames
/// for a wide (1920×1080) and a tall (1080×1920) cut, the boop sounds it uses, and `cues.txt` (when each sound
/// plays), for `Tools/promo/make-promo.sh` to turn into MP4s. Built-ins only, never the user's packs.
/// `BRBUDDY_PROMO=<dir>`; the app quits when it's done.
@MainActor
enum PromoFilm {
    static let fps = 30.0
    static let length = 30.0

    /// The boops in the "Boop them" scene: who, which reaction, and when (seconds).
    static let boops: [(id: String, boop: Boop, at: Double)] = [
        ("ember", .squish, 19.6), ("pebble", .giggle, 20.55), ("gremlin", .signature, 21.5),
    ]

    /// Every frame, or just the moments (seconds, comma-separated) in `BRBUDDY_PROMO_ONLY`, for a quick preview.
    static func frames() -> [Int] {
        if let only = ProcessInfo.processInfo.environment["BRBUDDY_PROMO_ONLY"] {
            return only.split(separator: ",").compactMap { Double($0) }.map { Int($0 * fps) }
        }
        return Array(0..<Int(length * fps))
    }

    static func render(to folder: URL) {
        let files = FileManager.default
        for (name, size) in [("wide", CGSize(width: 1920, height: 1080)), ("tall", CGSize(width: 1080, height: 1920))] {
            let dir = folder.appending(path: name)
            try? files.createDirectory(at: dir, withIntermediateDirectories: true)
            for frame in frames() {
                let renderer = ImageRenderer(content: PromoFrame(t: Double(frame) / fps, size: size))
                renderer.scale = 1
                renderer.isOpaque = true
                guard let image = renderer.cgImage else { continue }
                try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
                    .write(to: dir.appending(path: String(format: "%04d.png", frame)))
            }
        }
        var cues = ""
        for (index, item) in boops.enumerated() {
            let signature = BoopSignature.builtIn(item.id).signature
            let file = "boop-\(index).wav"
            try? BoopSound.wav(for: item.boop, signature: signature).write(to: folder.appending(path: file))
            cues += "\(item.at) \(file)\n"
        }
        try? cues.write(to: folder.appending(path: "cues.txt"), atomically: true, encoding: .utf8)
    }
}

// MARK: - Timing helpers

/// 0 before `start`, 1 after `end`, eased in between.
private func ramp(_ t: Double, _ start: Double, _ end: Double) -> Double {
    let x = min(max((t - start) / (end - start), 0), 1)
    return x * x * (3 - 2 * x)
}

/// A springy pop from 0 to 1 that overshoots a little, starting at `start`.
private func pop(_ t: Double, _ start: Double, length: Double = 0.55) -> Double {
    let x = min(max((t - start) / length, 0), 1)
    if x >= 1 { return 1 }
    return 1 - exp(-6 * x) * cos(x * 9)
}

private enum Palette {
    static let night = Color(red: 0.071, green: 0.059, blue: 0.122)
    static let night3 = Color(red: 0.141, green: 0.106, blue: 0.2)
    static let text = Color(red: 0.96, green: 0.94, blue: 0.98)
    static let muted = Color(red: 0.96, green: 0.94, blue: 0.98).opacity(0.66)
    static let peach = Color(red: 1, green: 0.78, blue: 0.55)
    static let coral = Color(red: 0.93, green: 0.45, blue: 0.52)
    static let mint = Color(red: 0.49, green: 0.88, blue: 0.63)
    static let amber = Color(red: 1, green: 0.62, blue: 0.26)
    static let warm = LinearGradient(colors: [peach, coral], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - One frame

/// The film at moment `t`: every scene that's on screen, cross-faded.
private struct PromoFrame: View {
    let t: Double
    let size: CGSize

    /// Scene windows (seconds). Each fades in and out over `fade`.
    static let scenes: [(start: Double, end: Double)] = [
        (0, 4.2), (4.2, 8.6), (8.6, 13.6), (13.6, 19.0), (19.0, 23.2), (23.2, 26.6), (26.6, 30.5),
    ]
    static let fade = 0.35

    var tall: Bool { size.height > size.width }
    /// One unit: 1 pt on a 1080-high wide frame.
    var u: CGFloat { min(size.width, size.height) / 1080 }

    var body: some View {
        ZStack {
            background
            ForEach(Array(Self.scenes.enumerated()), id: \.offset) { index, window in
                let visible = ramp(t, window.start - Self.fade / 2, window.start + Self.fade / 2)
                    * (1 - ramp(t, window.end - Self.fade / 2, window.end + Self.fade / 2))
                if visible > 0.001 {
                    scene(index, local: t - window.start)
                        .opacity(visible)
                        .scaleEffect(0.97 + 0.03 * visible)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Palette.night, Palette.night3], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.coral.opacity(0.22), .clear], center: .init(x: 0.5, y: tall ? 0.42 : 0.55),
                           startRadius: 0, endRadius: 760 * u)
                .offset(x: 40 * u * sin(t * 0.4), y: 30 * u * cos(t * 0.3))
        }
    }

    @ViewBuilder private func scene(_ index: Int, local: Double) -> some View {
        switch index {
        case 0: AgentAtWork(t: local, u: u, tall: tall)
        case 1: SteppingAway(t: local, u: u, tall: tall)
        case 2: KeepingWatch(t: local, u: u, tall: tall)
        case 3: MeetTheGang(t: local, u: u, tall: tall)
        case 4: BoopThem(t: local, start: Self.scenes[4].start, u: u, tall: tall)
        case 5: WelcomeBack(t: local, u: u, tall: tall)
        default: EndCard(t: local, u: u, tall: tall)
        }
    }
}

// MARK: - Shared pieces

/// A two-line caption: big gradient headline, smaller line under it. Slides up as it appears.
private struct Caption: View {
    let headline: String
    var line: String?
    let t: Double
    var delay = 0.15
    let u: CGFloat
    let tall: Bool

    var body: some View {
        let shown = ramp(t, delay, delay + 0.45)
        VStack(spacing: 14 * u) {
            Text(headline)
                .font(.system(size: (tall ? 96 : 84) * u, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.warm)
            if let line {
                Text(line)
                    .font(.system(size: (tall ? 46 : 38) * u, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .opacity(ramp(t, delay + 0.25, delay + 0.7))
            }
        }
        .multilineTextAlignment(.center)
        .lineSpacing(4 * u)
        .frame(maxWidth: (tall ? 960 : 1500) * u)
        .opacity(shown)
        .offset(y: 30 * u * (1 - shown))
    }
}

/// Caption on top, the scene's content in the middle.
private struct Stage<Content: View>: View {
    let u: CGFloat
    let tall: Bool
    let caption: Caption
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: (tall ? 90 : 40) * u) {
            caption
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Pill: View {
    let text: String
    let color: Color
    let u: CGFloat
    var body: some View {
        HStack(spacing: 12 * u) {
            Circle().fill(color).frame(width: 16 * u, height: 16 * u)
                .shadow(color: color, radius: 8 * u)
            Text(text).font(.system(size: 32 * u, weight: .semibold, design: .rounded)).foregroundStyle(Palette.text)
        }
        .padding(.horizontal, 30 * u).padding(.vertical, 16 * u)
        .background(Capsule().fill(.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1.5 * u))
    }
}

private func critter(_ id: String, _ mood: CompanionMood, t: Double, quiet: Bool = false, boop: Boop? = nil) -> CritterView {
    CritterView(design: .design(for: id), mood: mood, quiet: quiet, boop: boop, fixedTime: t)
}

// MARK: - Scenes

/// 0–4 s: a terminal with an agent busy on a long task.
private struct AgentAtWork: View {
    let t: Double, u: CGFloat, tall: Bool

    static let lines: [(String, Double)] = [
        ("› agent: refactor auth, fix the tests", 0.3),
        ("  Reading 48 files…", 1.0),
        ("  ✓ Updated 12 files", 1.6),
        ("  Running the test suite…", 2.2),
        ("  This could take a while ☕", 2.9),
    ]

    var body: some View {
        Stage(u: u, tall: tall, caption: Caption(headline: "Your agent's on a long task.", line: "And you could use a break.",
                                                  t: t, u: u, tall: tall)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10 * u) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.8)).frame(width: 18 * u) }
                }
                .padding(20 * u)
                VStack(alignment: .leading, spacing: 16 * u) {
                    ForEach(Array(Self.lines.enumerated()), id: \.offset) { _, line in
                        typed(line.0, from: line.1)
                    }
                }
                .padding(.horizontal, 36 * u).padding(.bottom, 40 * u)
            }
            .frame(width: (tall ? 960 : 1180) * u, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 26 * u).fill(Color.black.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 26 * u).strokeBorder(.white.opacity(0.1), lineWidth: 2 * u))
            .opacity(ramp(t, 0, 0.3))
        }
    }

    private func typed(_ text: String, from start: Double) -> some View {
        let count = Int(max(0, (t - start) * 60))
        let shown = String(text.prefix(count))
        let cursor = count < text.count && t >= start && Int(t * 4) % 2 == 0 ? "▌" : ""
        return Text(shown + cursor)
            .font(.system(size: (tall ? 40 : 36) * u, weight: .regular, design: .monospaced))
            .foregroundStyle(text.contains("✓") ? Palette.mint : Palette.text.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(height: (tall ? 52 : 44) * u, alignment: .leading)
    }
}

/// 4.2–8.6 s: you walk away, BRB covers the screen, Ember snoozes.
private struct SteppingAway: View {
    let t: Double, u: CGFloat, tall: Bool

    var body: some View {
        Stage(u: u, tall: tall, caption: Caption(headline: "BRB.", line: "Your Mac stays awake. A little buddy keeps watch.",
                                                  t: t, u: u, tall: tall)) {
            VStack(spacing: 30 * u) {
                critter("ember", .resting, t: 30 + t)
                    .frame(width: (tall ? 760 : 620) * u, height: (tall ? 660 : 540) * u)
                    .scaleEffect(0.6 + 0.4 * pop(t, 0.2, length: 0.8))
                Pill(text: "Keeping your Mac awake", color: Palette.mint, u: u)
                    .opacity(ramp(t, 1.2, 1.6))
            }
        }
    }
}

/// 8.6–13.6 s: Ember shows what the agent is doing.
private struct KeepingWatch: View {
    let t: Double, u: CGFloat, tall: Bool

    var body: some View {
        let (mood, label, color): (CompanionMood, String, Color) =
            t < 1.7 ? (.working, "Agent working…", Palette.amber)
            : t < 3.4 ? (.waiting, "Your agent needs you", Palette.coral)
            : (.finished, "All done ✓", Palette.mint)
        let switchAt = t < 1.7 ? 0 : t < 3.4 ? 1.7 : 3.4
        Stage(u: u, tall: tall, caption: Caption(headline: "It knows what your agent's up to.",
                                                  line: "Working, needs you, all done: at a glance, across the room.",
                                                  t: t, u: u, tall: tall)) {
            VStack(spacing: 30 * u) {
                critter("ember", mood, t: 50 + t)
                    .frame(width: (tall ? 760 : 620) * u, height: (tall ? 660 : 540) * u)
                    .scaleEffect(switchAt == 0 ? 1 : 0.92 + 0.08 * pop(t, switchAt, length: 0.45))
                Pill(text: label, color: color, u: u)
                    .scaleEffect(switchAt == 0 ? 1 : 0.85 + 0.15 * pop(t, switchAt, length: 0.4))
            }
        }
    }
}

/// 13.6–19 s: all six built-ins pop in.
private struct MeetTheGang: View {
    let t: Double, u: CGFloat, tall: Bool

    static let cast: [(id: String, mood: CompanionMood)] = [
        ("ember", .greeting), ("pebble", .resting), ("prism", .working),
        ("comet", .finished), ("drift", .waiting), ("gremlin", .greeting),
    ]

    var body: some View {
        let columns = tall ? 2 : 3
        let cell = CGSize(width: (tall ? 480 : 580) * u, height: (tall ? 470 : 370) * u)
        Stage(u: u, tall: tall, caption: Caption(headline: "Meet the gang.", line: "Six little companions. Or design your own.",
                                                  t: t, u: u, tall: tall)) {
            Grid(horizontalSpacing: 10 * u, verticalSpacing: 6 * u) {
                ForEach(0..<(Self.cast.count / columns), id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            member(row * columns + column, cell: cell)
                        }
                    }
                }
            }
        }
    }

    private func member(_ index: Int, cell: CGSize) -> some View {
        let item = Self.cast[index]
        let name = CompanionCatalog.builtIn(id: item.id)?.name ?? item.id
        let shown = pop(t, 0.5 + Double(index) * 0.32)
        return VStack(spacing: 0) {
            critter(item.id, item.mood, t: 70 + t + Double(index) * 1.3, quiet: true)
                .frame(width: cell.width * 0.9, height: cell.height * 0.78)
            Text(name)
                .font(.system(size: 36 * u, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
        }
        .frame(width: cell.width, height: cell.height)
        .scaleEffect(max(shown, 0.001))
        .opacity(min(1, shown * 2))
    }
}

/// 19–23.2 s: a pointer boops three companions in turn.
private struct BoopThem: View {
    let t: Double, start: Double, u: CGFloat, tall: Bool

    var body: some View {
        let size = CGSize(width: (tall ? 620 : 520) * u, height: (tall ? 430 : 460) * u)
        Stage(u: u, tall: tall, caption: Caption(headline: "Boop them.", line: "Everyone has their own reaction. And sound.",
                                                  t: t, u: u, tall: tall)) {
            let layout = tall ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 60 * u))
            layout {
                ForEach(Array(PromoFilm.boops.enumerated()), id: \.offset) { index, item in
                    booped(item.id, item.boop, at: item.at - start, index: index)
                        .frame(width: size.width, height: size.height)
                        .overlay(alignment: .center) { pointer(at: item.at - start, index: index) }
                }
            }
        }
    }

    private func booped(_ id: String, _ boop: Boop, at: Double, index: Int) -> some View {
        let p = (t - at) / boop.duration
        let active = p >= 0 && p < 1
        let bubble = boop == .signature ? BoopSignature.builtIn(id).bubble : nil
        return ZStack {
            critter(id, active ? .greeting : .resting, t: 90 + t + Double(index), quiet: true, boop: active ? boop : nil)
                .boopMotion(boop, progress: active ? p : 1)
            if active { BoopFlair(boop: boop, progress: p, signatureBubble: bubble) }
        }
    }

    /// A Mac pointer that glides in just before the boop and clicks.
    private func pointer(at: Double, index: Int) -> some View {
        let arrive = ramp(t, at - 0.45, at - 0.05)
        let leave = ramp(t, at + 0.25, at + 0.55)
        let press = t >= at - 0.05 && t < at + 0.12 ? 0.82 : 1.0
        return Image(systemName: "cursorarrow")
            .font(.system(size: 64 * u, weight: .regular))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 6 * u, y: 3 * u)
            .scaleEffect(press)
            .offset(x: (60 + 200 * (1 - arrive)) * u, y: (40 + 160 * (1 - arrive)) * u)
            .opacity(arrive * (1 - leave))
    }
}

/// 23.2–26.6 s: you come back, Ember says hi, Touch ID unlocks.
private struct WelcomeBack: View {
    let t: Double, u: CGFloat, tall: Bool

    var body: some View {
        let unlocked = t >= 1.9
        Stage(u: u, tall: tall, caption: Caption(headline: "Back already?", line: "Touch ID, and you're straight in.",
                                                  t: t, u: u, tall: tall)) {
            let layout = tall ? AnyLayout(VStackLayout(spacing: 40 * u)) : AnyLayout(HStackLayout(spacing: 80 * u))
            layout {
                critter("ember", unlocked ? .finished : .greeting, t: 110 + t, quiet: true)
                    .frame(width: 520 * u, height: 450 * u)
                VStack(spacing: 26 * u) {
                    ZStack {
                        Circle().fill(.white.opacity(0.06)).frame(width: 170 * u, height: 170 * u)
                        Circle().strokeBorder(unlocked ? Palette.mint : Palette.coral, lineWidth: 4 * u)
                            .frame(width: 170 * u, height: 170 * u)
                        Image(systemName: unlocked ? "checkmark" : "touchid")
                            .font(.system(size: 88 * u, weight: unlocked ? .bold : .light))
                            .foregroundStyle(unlocked ? Palette.mint : Palette.coral)
                            .scaleEffect(unlocked ? pop(t, 1.9, length: 0.4) : 1 + 0.05 * sin(t * 8))
                    }
                    Text(unlocked ? "Welcome back!" : "Touch ID to unlock")
                        .font(.system(size: 38 * u, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                .padding(50 * u)
                .frame(width: 520 * u)
                .background(RoundedRectangle(cornerRadius: 34 * u).fill(.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 34 * u).strokeBorder(.white.opacity(0.1), lineWidth: 2 * u))
                .opacity(ramp(t, 0.4, 0.8))
            }
        }
    }
}

/// 26.6–30 s: icon, name, website.
private struct EndCard: View {
    let t: Double, u: CGFloat, tall: Bool

    var body: some View {
        let u = self.u * (tall ? 1.3 : 1)
        VStack(spacing: 34 * u) {
            AppIconArt(option: .brbBubble)
                .frame(width: 1024, height: 1024)
                .scaleEffect(380 * u / 1024)
                .frame(width: 380 * u, height: 380 * u)
                .scaleEffect(max(pop(t, 0.1, length: 0.7), 0.001))
            Text("BRBuddy")
                .font(.system(size: 120 * u, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.warm)
                .opacity(ramp(t, 0.4, 0.8))
            Text("BRB, my agent's got this.")
                .font(.system(size: 46 * u, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text)
                .opacity(ramp(t, 0.7, 1.1))
            Text("Free and open source for Mac")
                .font(.system(size: 36 * u, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.muted)
                .opacity(ramp(t, 0.9, 1.3))
            Text("brbuddy.app")
                .font(.system(size: 50 * u, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.night)
                .padding(.horizontal, 50 * u).padding(.vertical, 20 * u)
                .background(Capsule().fill(Palette.warm))
                .scaleEffect(0.9 + 0.1 * pop(t, 1.2, length: 0.5))
                .opacity(ramp(t, 1.2, 1.5))
                .padding(.top, 16 * u)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(1 - ramp(t, 3.15, 3.4))
    }
}
#endif
