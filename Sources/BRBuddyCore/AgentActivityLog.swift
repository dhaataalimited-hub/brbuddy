import Foundation

/// A rolling feed of what agents did, built from hook events. The terminal mirror's fallback: it needs no tmux and
/// no permissions. Pure: events and times are passed in.
public struct AgentActivityLog: Sendable {
    public struct Entry: Equatable, Sendable {
        public var time: Date
        public var agent: AgentKind
        public var activity: AgentActivity
        public var project: String?
        public var text: String
    }

    public static let capacity = 80
    public private(set) var entries: [Entry] = []

    public init() {}

    public mutating func record(_ event: AgentEvent) {
        guard let activity = event.activity else { return }
        let text: String
        switch activity {
        case .started: text = "session started"
        case .working: text = event.detail ?? (event.event.lowercased().contains("prompt") ? "got a new prompt" : "working")
        case .waiting: text = event.detail.map { "needs you: \($0)" } ?? "needs you"
        case .finished: text = "finished"
        case .ended: text = "session closed"
        }
        let entry = Entry(time: event.time, agent: event.agent, activity: activity,
                          project: event.cwd.map { ($0 as NSString).lastPathComponent }, text: text)
        if let last = entries.last, last.agent == entry.agent, last.text == entry.text, last.activity == entry.activity {
            entries[entries.count - 1] = entry  // Same thing again: just refresh the time.
        } else {
            entries.append(entry)
        }
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
    }

    /// The feed as styled lines, oldest first: time, icon, agent and project, then what happened.
    public func terminalLines(timeZone: TimeZone = .current) -> [TerminalLine] {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = timeZone
        var dim = TerminalStyle(); dim.dim = true
        return entries.map { entry in
            var icon = TerminalStyle(), label = TerminalStyle()
            label.bold = true
            let symbol: String
            switch entry.activity {
            case .working: symbol = "⚙"; icon.foreground = .indexed(12)
            case .waiting: symbol = "✋"; icon.foreground = .indexed(11)
            case .finished: symbol = "✓"; icon.foreground = .indexed(10)
            case .started, .ended: symbol = "·"; icon.foreground = .indexed(8)
            }
            let who = entry.agent.displayName + (entry.project.map { " · \($0)" } ?? "")
            return [
                TerminalRun(formatter.string(from: entry.time) + "  ", style: dim),
                TerminalRun(symbol + " ", style: icon),
                TerminalRun(who, style: label),
                TerminalRun("  " + entry.text),
            ]
        }
    }
}
