#if DEBUG
import AppKit
import BRBuddyCore
import SwiftUI

/// Debug builds only: renders every built-in companion in every mood to one PNG, for reviewing the art without
/// opening the away screen. Triggered by `BRBUDDY_COMPANION_SHEET=<file.png>` (see `AppDelegate`).
@MainActor
enum CompanionContactSheet {
    static func render(to url: URL) {
        let sheet = Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Text("")
                ForEach(CompanionMood.allCases, id: \.self) { mood in
                    Text(mood.rawValue).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                }
            }
            ForEach(CompanionCatalog.builtIns) { critter in
                GridRow {
                    VStack(alignment: .leading) {
                        Text(critter.name).font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(critter.agent.displayName).font(.system(size: 11, design: .rounded)).opacity(0.6)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 110, alignment: .leading)
                    ForEach(CompanionMood.allCases, id: \.self) { mood in
                        CritterView(design: .design(for: critter.id), mood: mood).frame(width: 170, height: 156)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.09, green: 0.07, blue: 0.13))

        save(sheet, to: url)
    }

    /// Every battery reaction: the away-screen badge above Ember reacting to it. `BRBUDDY_BATTERY_SHEET=<file.png>`.
    static func renderBattery(to url: URL) {
        let cases: [(String, BatteryStatus, BatteryReaction)] = [
            ("on battery", BatteryStatus(percent: 72, isPluggedIn: false, isCharging: false, minutesRemaining: 250), .none),
            ("plugged in", BatteryStatus(percent: 41, isPluggedIn: true, isCharging: true), .pluggedIn),
            ("charging", BatteryStatus(percent: 41, isPluggedIn: true, isCharging: true, minutesRemaining: 83), .charging),
            ("full", BatteryStatus(percent: 100, isPluggedIn: true, isCharging: false), .full),
            ("unplugged", BatteryStatus(percent: 99, isPluggedIn: false, isCharging: false), .unplugged),
            ("low power", BatteryStatus(percent: 55, isPluggedIn: false, isCharging: false, isLowPowerMode: true,
                                        minutesRemaining: 190), .lowPower),
            ("low", BatteryStatus(percent: 18, isPluggedIn: false, isCharging: false, minutesRemaining: 34), .low),
            ("critical", BatteryStatus(percent: 6, isPluggedIn: false, isCharging: false, minutesRemaining: 9), .critical),
        ]
        let sheet = LazyVGrid(columns: Array(repeating: GridItem(.fixed(330), spacing: 16), count: 4), spacing: 16) {
            ForEach(cases, id: \.0) { name, status, reaction in
                VStack(spacing: 10) {
                    Text(name).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    BatteryBadge(status: status, reaction: reaction)
                    ZStack {
                        CritterView(design: .design(for: "ember"), mood: reaction.moodOverride ?? .resting, battery: reaction,
                                    quiet: reaction.bubble != nil)
                        BatteryFlair(reaction: reaction, talks: true)
                    }
                    .frame(width: 240, height: 210)
                }
                .frame(height: 340)
            }
        }
        .padding(24)
        .background(Color(red: 0.09, green: 0.07, blue: 0.13))
        save(sheet, to: url)
    }

    /// Every boop mid-reaction on Ember, plus each sound as a WAV beside the PNG. `BRBUDDY_BOOP_SHEET=<file.png>`.
    static func renderBoops(to url: URL) {
        let sheet = HStack(spacing: 16) {
            ForEach(Boop.allCases, id: \.self) { boop in
                VStack(spacing: 8) {
                    Text(boop.rawValue).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    ZStack {
                        CritterView(design: .design(for: "ember"), mood: .greeting, quiet: true, boop: boop)
                            .boopMotion(boop, progress: boop == .spin ? 0.75 : 0.35)
                        BoopFlair(boop: boop, progress: 0.35)
                    }
                    .frame(width: 240, height: 210)
                }
            }
        }
        .padding(24)
        .background(Color(red: 0.09, green: 0.07, blue: 0.13))
        save(sheet, to: url)
        for boop in Boop.allCases {
            try? BoopSound.wav(for: boop).write(to: url.deletingLastPathComponent().appending(path: "boop-\(boop.rawValue).wav"))
        }
        for signature in BoopSignature.allCases {
            try? BoopSound.wav(for: .signature, signature: signature)
                .write(to: url.deletingLastPathComponent().appending(path: "signature-\(signature.rawValue).wav"))
        }
    }

    /// Companion Studio's window and a sample design's spritesheets, saved into `folder`. `BRBUDDY_STUDIO_SNAPSHOT=<dir>`.
    static func renderStudio(library: CompanionLibrary, to folder: URL) async {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560), styleMask: [.titled],
                              backing: .buffered, defer: false)
        let host = NSHostingView(rootView: CompanionStudioView(library: library))
        window.contentView = host
        window.orderFront(nil)
        try? await Task.sleep(for: .seconds(1.5))
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: "studio-window.png"))
        }
        window.orderOut(nil)
        var generator = SeededGenerator(state: 11)
        let design = StudioDesign.random(using: &generator)
        if let sheet = try? await StudioSheetRenderer.render(design, still: false) {
            try? sheet.write(to: folder.appending(path: "studio-sheet.png"))
        }
        if let sheet = try? await StudioSheetRenderer.render(design, still: true) {
            try? sheet.write(to: folder.appending(path: "studio-sheet-still.png"))
        }
    }

    /// Every Studio mouth style in every mood, on the starter design. `BRBUDDY_MOUTH_SHEET=<file.png>`.
    static func renderMouths(to url: URL) {
        let sheet = Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Text("")
                ForEach(CompanionMood.allCases, id: \.self) { mood in
                    Text(mood.rawValue).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                }
            }
            ForEach(StudioDesign.Mouth.allCases, id: \.self) { mouth in
                GridRow {
                    Text(mouth.rawValue).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(width: 80, alignment: .leading)
                    ForEach(CompanionMood.allCases, id: \.self) { mood in
                        CritterView(design: CritterDesign(studio: starter(mouth: mouth)), mood: mood, quiet: true, fixedTime: 41)
                            .frame(width: 150, height: 130)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.09, green: 0.07, blue: 0.13))
        save(sheet, to: url)
    }

    private static func starter(mouth: StudioDesign.Mouth) -> StudioDesign {
        var design = StudioDesign.starter
        design.mouth = mouth
        return design
    }

    /// A repeatable random generator for debug renders.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    /// App icon candidates, each a 1024 px PNG in Apple's macOS icon grid (an 824 px rounded square with room for its
    /// shadow). `BRBUDDY_ICON_OPTIONS=<dir>`.
    static func renderIconOptions(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for option in AppIconArt.Option.allCases {
            let renderer = ImageRenderer(content: AppIconArt(option: option))
            renderer.scale = 1
            guard let image = renderer.cgImage else { continue }
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?
                .write(to: folder.appending(path: "icon-\(option.rawValue).png"))
        }
    }

    /// Art for the website (site/): every built-in companion in every mood as its own transparent PNG,
    /// `<id>-<mood>.png`, plus Ember's battery and boop moments. Built-ins only, never the user's packs.
    /// `BRBUDDY_SITE_ART=<dir>`.
    static func renderSiteArt(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for critter in CompanionCatalog.builtIns {
            for mood in CompanionMood.allCases {
                save(CritterView(design: .design(for: critter.id), mood: mood, fixedTime: 41).frame(width: 260, height: 240),
                     to: folder.appending(path: "\(critter.id)-\(mood.rawValue).png"))
            }
        }
        let ember = CritterDesign.design(for: "ember")
        for reaction in [BatteryReaction.pluggedIn, .low, .lowPower] {
            save(ZStack {
                CritterView(design: ember, mood: reaction.moodOverride ?? .resting, battery: reaction, quiet: true, fixedTime: 41)
                BatteryFlair(reaction: reaction, talks: true)
            }.frame(width: 260, height: 240), to: folder.appending(path: "ember-battery-\(reaction).png"))
        }
        for boop in Boop.allCases {
            save(ZStack {
                CritterView(design: ember, mood: .greeting, quiet: true, boop: boop, fixedTime: 41)
                    .boopMotion(boop, progress: boop == .spin ? 0.75 : 0.35)
                BoopFlair(boop: boop, progress: 0.35)
            }.frame(width: 260, height: 240), to: folder.appending(path: "ember-boop-\(boop.rawValue).png"))
        }
        save(BatteryBadge(status: BatteryStatus(percent: 72, isPluggedIn: false, isCharging: false, minutesRemaining: 250),
                          reaction: .none), to: folder.appending(path: "battery-badge.png"))
    }

    private static func save(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
/// The app icon artwork: Ember on a rounded square, drawn with the companion code itself.
struct AppIconArt: View {
    enum Option: String, CaseIterable {
        case nightNap = "1-night-nap", brbBubble = "2-brb-bubble", peekaboo = "3-peekaboo", sunrise = "4-sunrise"
    }
    let option: Option

    private let canvas: CGFloat = 1024, tile: CGFloat = 824

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(.black.opacity(0.35))
                .frame(width: tile, height: tile)
                .blur(radius: 14)
                .offset(y: 12)
            content
                .frame(width: tile, height: tile)
                .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 3))
        }
        .frame(width: canvas, height: canvas)
    }

    private let ember = CritterDesign.design(for: "ember")
    private let night = LinearGradient(colors: [Color(red: 0.2, green: 0.14, blue: 0.36), Color(red: 0.07, green: 0.05, blue: 0.13)],
                                       startPoint: .top, endPoint: .bottom)

    @ViewBuilder private var content: some View {
        switch option {
        case .nightNap:
            ZStack {
                night
                stars
                Circle().fill(Color(red: 1, green: 0.93, blue: 0.7)).frame(width: 110, height: 110)
                    .overlay(Circle().fill(Color(red: 0.2, green: 0.14, blue: 0.36)).frame(width: 96, height: 96).offset(x: 34, y: -22))
                    .offset(x: 250, y: -250)
                CritterView(design: ember, mood: .resting, fixedTime: 41).frame(width: 800, height: 693).offset(y: 95)
            }
        case .brbBubble:
            ZStack {
                LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.55), Color(red: 0.93, green: 0.45, blue: 0.52)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                CritterView(design: ember, mood: .greeting, quiet: true, fixedTime: 41).frame(width: 780, height: 676).offset(x: -20, y: 110)
                BubbleLabel(text: "BRB").scaleEffect(4.6).offset(x: 160, y: -250)
            }
        case .peekaboo:
            ZStack {
                night
                stars
                RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color(red: 0.13, green: 0.1, blue: 0.2))
                    .frame(width: 700, height: 300).offset(y: 330)
                CritterView(design: ember, mood: .resting, quiet: true, fixedTime: 41).frame(width: 820, height: 711).offset(y: 120)
                    .mask(Rectangle().frame(width: 824, height: 592).offset(y: -116))
                BubbleLabel(text: "BRB", tint: Color(red: 1, green: 0.85, blue: 0.4)).scaleEffect(4.4).offset(x: 0, y: -270)
            }
        case .sunrise:
            ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.32), Color(red: 0.55, green: 0.3, blue: 0.55),
                                        Color(red: 1, green: 0.66, blue: 0.46)], startPoint: .top, endPoint: .bottom)
                stars.opacity(0.6)
                CritterView(design: ember, mood: .finished, fixedTime: 41).frame(width: 800, height: 693).offset(y: 80)
            }
        }
    }

    private var stars: some View {
        let points: [(CGFloat, CGFloat, CGFloat)] = [(-300, -300, 10), (-170, -340, 6), (-330, -120, 7), (40, -340, 8),
                                                     (330, -60, 6), (-250, -220, 5), (150, -250, 5), (300, -330, 7)]
        return ZStack {
            ForEach(points.indices, id: \.self) { i in
                Circle().fill(.white.opacity(0.85)).frame(width: points[i].2, height: points[i].2)
                    .offset(x: points[i].0, y: points[i].1)
            }
        }
    }
}
#endif
