import CoreGraphics
import Foundation

/// The first-launch tour: its steps, whether it has been seen, and where its panels go on screen.
///
/// On first launch the companion hangs under the menu bar icon; clicking it walks through these steps. The tour is
/// marked seen when it is finished, skipped or closed, and can be reopened from the menu.
public enum FirstLaunchTour {
    public enum Step: Int, CaseIterable, Sendable {
        case agents, companion, extras, tryBRB

        public var title: String {
            switch self {
            case .agents: "Connect your agent"
            case .companion: "Pick a companion"
            case .extras: "A few extras"
            case .tryBRB: "Try BRB"
            }
        }

        /// The step after this one; the last step, Try BRB, stays put. It comes last because trying BRB covers the
        /// screen and ends the tour, so nothing has to come back afterwards.
        public var next: Step { Step(rawValue: rawValue + 1) ?? .tryBRB }
        /// The step before this one; `agents` stays `agents`.
        public var previous: Step { Step(rawValue: rawValue - 1) ?? .agents }
        public var isLast: Bool { self == Step.allCases.last }
        /// "Step 2 of 4".
        public var counter: String { "Step \(rawValue + 1) of \(Step.allCases.count)" }
    }

    static let seenKey = "tour.seen"

    /// Whether the tour should open by itself at launch: only until it has been finished, skipped or closed once.
    public static func shouldShowAtLaunch(store: UserDefaults = .standard) -> Bool {
        !store.bool(forKey: seenKey)
    }

    public static func markSeen(store: UserDefaults = .standard) {
        store.set(true, forKey: seenKey)
    }

    /// Whether a menu bar item at `item` can be seen on the screen at `screen` (both Cocoa coordinates): it is inside
    /// the screen's width, in its top band, and not hidden behind the notch. `notchLeft` and `notchRight` are the
    /// screen's usable areas beside the notch (`NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`), nil on
    /// screens without one; they may be given relative to the screen or in global coordinates.
    public static func isVisible(item: CGRect, screen: CGRect, notchLeft: CGRect? = nil,
                                 notchRight: CGRect? = nil) -> Bool {
        guard item.width > 0, item.midX >= screen.minX, item.midX <= screen.maxX,
              item.minY >= screen.maxY - 60, item.minY <= screen.maxY else { return false }
        guard var left = notchLeft, var right = notchRight else { return true }
        // Relative to the screen: shift into global coordinates.
        if screen.minX != 0, right.maxX <= screen.width + 1, !right.intersects(screen) {
            left = left.offsetBy(dx: screen.minX, dy: screen.minY)
            right = right.offsetBy(dx: screen.minX, dy: screen.minY)
        }
        // In the gap between the two areas is behind the notch.
        return item.maxX <= left.maxX + 1 || item.minX >= right.minX - 1
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
