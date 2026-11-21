import BRBuddyCore
import SwiftUI

/// Shows whichever companion is chosen for `agent`, acting out `mood`: a built-in critter or a community pack.
/// With `canBoop`, clicking it plays one of five reactions (`Boop`), with a sound unless `boopSounds` is off.
struct CompanionView: View {
    let library: CompanionLibrary
    let mood: CompanionMood
    let agent: AgentKind?
    /// What the battery is up to; the companion reacts to it.
    var battery: BatteryReaction = .none
    /// On battery: the body holds still and only the face moves.
    var still = false
    var canBoop = false
    var boopSounds = true

    @State private var boop: BoopEvent?
    @State private var picker = BoopPicker()

    var body: some View {
        TimelineView(.animation(paused: boop == nil)) { timeline in
            let progress = boop?.progress(at: timeline.date)
            ZStack {
                companion
                    .modifier(BoopMotionModifier(boop: progress == nil ? nil : boop?.boop, progress: progress ?? 0))
                if battery != .none {
                    BatteryFlair(reaction: battery, talks: batteryTalks && boop == nil)
                }
                if let boop, let progress {
                    BoopFlair(boop: boop.boop, progress: progress, signatureBubble: signature.bubble)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if canBoop { boopNow() } }
    }

    @ViewBuilder private var companion: some View {
        switch library.resolved(for: agent) {
        case .builtIn(let builtIn):
            CritterView(design: .design(for: builtIn.id), mood: mood, battery: battery,
                        quiet: batteryTalks || boop != nil, still: still, boop: boop?.boop)
        case .pack(let id):
            SpritePackView(frames: library.frames(pack: id, mood: boop?.boop.packMood ?? mood, still: still && boop == nil))
        }
    }

    /// The battery gets the speech bubble unless the agent needs the user or someone is unlocking.
    private var batteryTalks: Bool {
        battery.bubble != nil && mood != .waiting && mood != .greeting
    }

    /// This companion's own boop sound and line: built-ins have one each; packs name theirs in `pet.json`.
    private var signature: (sound: BoopSignature, bubble: String) {
        switch library.resolved(for: agent) {
        case .builtIn(let builtIn):
            let own = BoopSignature.builtIn(builtIn.id)
            return (own.signature, own.bubble)
        case .pack(let id):
            let pack = library.pack(id: id)
            return (pack?.boopSignature ?? .sparkle, pack?.boopBubble ?? Boop.signature.bubble)
        }
    }

    private func boopNow() {
        let event = BoopEvent(picker.next(), at: Date())
        boop = event
        if boopSounds { BoopPlayer.play(event.boop, signature: signature.sound) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(event.boop.duration))
            if boop == event { boop = nil }
        }
    }
}

private struct BoopMotionModifier: ViewModifier {
    let boop: Boop?
    let progress: Double

    func body(content: Content) -> some View {
        if let boop { content.boopMotion(boop, progress: progress) } else { content }
    }
}

/// Plays a row of spritesheet frames at 8 frames a second.
struct SpritePackView: View {
    let frames: [CGImage]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8)) { timeline in
            if frames.isEmpty {
                ProgressView().controlSize(.small)
            } else {
                let index = Int(timeline.date.timeIntervalSinceReferenceDate * 8) % frames.count
                Image(decorative: frames[index], scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .aspectRatio(CGFloat(CompanionPack.cellWidth) / CGFloat(CompanionPack.cellHeight), contentMode: .fit)
    }
}
