import Foundation

/// What the away screen mirrors below the companion. Off by default: anything shown is visible to whoever walks past.
public enum TerminalMirrorMode: String, CaseIterable, Sendable, Identifiable {
    case off
    /// tmux if the agent runs in it, else a terminal window via Accessibility, else the agent activity feed.
    case automatic
    case tmux
    case terminalWindow
    case activityFeed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "Off"
        case .automatic: "Automatic"
        case .tmux: "tmux pane"
        case .terminalWindow: "Terminal window"
        case .activityFeed: "Agent activity feed"
        }
    }

    static let key = "mirror.mode"

    public static func load(from store: UserDefaults = .standard) -> TerminalMirrorMode {
        store.string(forKey: key).flatMap(TerminalMirrorMode.init(rawValue:)) ?? .off
    }

    public func save(to store: UserDefaults = .standard) {
        store.set(rawValue, forKey: Self.key)
    }
}
