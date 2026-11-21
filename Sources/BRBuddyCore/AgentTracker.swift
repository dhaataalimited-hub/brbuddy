import Foundation

/// Keeps the latest state of every agent session from hook events, and sums them up. Pure: time is passed in.
public struct AgentTracker: Sendable {
    public struct Session: Equatable, Sendable, Identifiable {
        public var agent: AgentKind
        public var id: String
        public var cwd: String?
        public var activity: AgentActivity
        public var lastEvent: Date
        /// Where the session runs, for jumping to it from the menu.
        public var terminal: TerminalLocation? = nil

        /// The project folder's name, for display.
        public var projectName: String? { cwd.map { ($0 as NSString).lastPathComponent } }
    }

    /// Overall state, most urgent first.
    public enum Summary: Equatable, Sendable {
        case waiting(Session)
        case working(Session)
        case finished(Session)
        case none

        /// An agent is busy or needs the user: keep the Mac awake and let BRB start on its own.
        public var isActive: Bool {
            switch self {
            case .waiting, .working: true
            case .finished, .none: false
            }
        }
    }

    /// A session that's been "working" this long with no events is assumed to have died (crashed, killed).
    public static let workingTimeout: TimeInterval = 30 * 60
    /// A session waiting on the user stays relevant this long.
    public static let waitingTimeout: TimeInterval = 4 * 60 * 60
    /// A finished session is shown this long, then forgotten.
    public static let finishedTimeout: TimeInterval = 15 * 60

    public private(set) var sessions: [String: Session] = [:]

    public init() {}

    private static func key(_ agent: AgentKind, _ id: String) -> String { "\(agent.rawValue):\(id)" }

    public mutating func apply(_ event: AgentEvent) {
        guard let activity = event.activity else { return }
        let key = Self.key(event.agent, event.session)
        if activity == .ended {
            sessions.removeValue(forKey: key)
            return
        }
        sessions[key] = Session(agent: event.agent, id: event.session, cwd: event.cwd ?? sessions[key]?.cwd,
                                activity: activity, lastEvent: event.time,
                                terminal: event.terminal ?? sessions[key]?.terminal)
    }

    /// Drops sessions that have gone quiet for longer than their state allows.
    public mutating func prune(now: Date) {
        sessions = sessions.filter { _, session in
            let age = now.timeIntervalSince(session.lastEvent)
            switch session.activity {
            case .working: return age < Self.workingTimeout
            case .waiting: return age < Self.waitingTimeout
            case .started, .finished: return age < Self.finishedTimeout
            case .ended: return false
            }
        }
    }

    public var summary: Summary {
        let newestFirst = sessions.values.sorted { $0.lastEvent > $1.lastEvent }
        if let s = newestFirst.first(where: { $0.activity == .waiting }) { return .waiting(s) }
        if let s = newestFirst.first(where: { $0.activity == .working }) { return .working(s) }
        if let s = newestFirst.first(where: { $0.activity == .finished }) { return .finished(s) }
        return .none
    }

    /// Sessions for display, most recent first.
    public var orderedSessions: [Session] { sessions.values.sorted { $0.lastEvent > $1.lastEvent } }
}
