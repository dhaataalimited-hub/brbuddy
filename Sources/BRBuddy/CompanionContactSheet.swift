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

        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
