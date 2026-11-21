import BRBuddyCore
import SwiftUI

/// Shows whichever companion is chosen for `agent`, acting out `mood`: a built-in critter or a community pack.
struct CompanionView: View {
    let library: CompanionLibrary
    let mood: CompanionMood
    let agent: AgentKind?
    /// What the battery is up to; the companion reacts to it.
    var battery: BatteryReaction = .none

    var body: some View {
        ZStack {
            switch library.resolved(for: agent) {
            case .builtIn(let builtIn):
                CritterView(design: .design(for: builtIn.id), mood: mood, battery: battery, quiet: batteryTalks)
            case .pack(let id):
                SpritePackView(frames: library.frames(pack: id, mood: mood))
            }
            if battery != .none {
                BatteryFlair(reaction: battery, talks: batteryTalks)
            }
        }
    }

    /// The battery gets the speech bubble unless the agent needs the user or someone is unlocking.
    private var batteryTalks: Bool {
        battery.bubble != nil && mood != .waiting && mood != .greeting
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
