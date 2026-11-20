import BRBuddyCore
import SwiftUI

/// Shows whichever companion is chosen for `agent`, acting out `mood`: a built-in critter or a community pack.
struct CompanionView: View {
    let library: CompanionLibrary
    let mood: CompanionMood
    let agent: AgentKind?

    var body: some View {
        switch library.resolved(for: agent) {
        case .builtIn(let builtIn):
            CritterView(design: .design(for: builtIn.id), mood: mood)
        case .pack(let id):
            SpritePackView(frames: library.frames(pack: id, mood: mood))
        }
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
