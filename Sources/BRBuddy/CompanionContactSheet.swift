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

    /// A repeatable random generator for debug renders.
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    private static func save(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
