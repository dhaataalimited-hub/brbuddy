import CoreGraphics
import Foundation

/// The first-launch tour: its steps, whether it has been seen, and where its panels go on screen.
///
/// On first launch the companion hangs under the menu bar icon; clicking it walks through these steps. The tour is
/// marked seen when it is finished, skipped or closed, and can be reopened from the menu.
public enum FirstLaunchTour {
    public enum Step: Int, CaseIterable, Sendable {
        case agents, tryBRB, companion, extras, done

        public var title: String {
            switch self {
            case .agents: "Connect your agent"
            case .tryBRB: "Try BRB"
            case .companion: "Pick a companion"
            case .extras: "A few extras"
            case .done: "You're all set"
            }
        }

        /// The step after this one; `done` stays `done`.
        public var next: Step { Step(rawValue: rawValue + 1) ?? .done }
        /// The step before this one; `agents` stays `agents`.
        public var previous: Step { Step(rawValue: rawValue - 1) ?? .agents }
        /// "Step 2 of 4", or nil for the closing screen.
        public var counter: String? {
            self == .done ? nil : "Step \(rawValue + 1) of \(Step.allCases.count - 1)"
        }
    }

    static let seenKey = "tour.seen"

    /// Whether the tour should open by itself at launch: only until it has been finished, skipped or closed once.
    public static func shouldShowAtLaunch(store: UserDefaults = .standard) -> Bool {
        !store.bool(forKey: seenKey)
    }

    public static func markSeen(store: UserDefaults = .standard) {
        store.set(true, forKey: seenKey)
    }

    /// Where to put a panel of `size` so it hangs just under the menu bar item at `anchor`, kept inside `visible`
    /// (the screen's visible frame, Cocoa coordinates). With no anchor, or one off to the side of the screen (the
    /// icon is behind the notch or hidden by a menu bar organiser), the panel goes in the upper middle instead.
    public static func origin(size: CGSize, anchor: CGRect?, visible: CGRect, below: CGFloat = 0,
                              margin: CGFloat = 8) -> CGPoint {
        let top = visible.maxY - below
        guard let anchor, anchor.midX >= visible.minX, anchor.midX <= visible.maxX else {
            return CGPoint(x: visible.midX - size.width / 2,
                           y: min(top - size.height, visible.midY + visible.height / 6 - size.height / 2))
        }
        let x = min(max(anchor.midX - size.width / 2, visible.minX + margin), visible.maxX - size.width - margin)
        return CGPoint(x: x, y: top - size.height)
    }
}
