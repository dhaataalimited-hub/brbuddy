import Foundation

/// One hook firing, as `brbuddy-hook` sends it to the app: one JSON object per line over the local socket.
public struct AgentEvent: Codable, Equatable, Sendable {
    public var agent: AgentKind
    public var event: String
    public var session: String
    /// The project folder the agent is working in, if the agent said.
    public var cwd: String?
    public var time: Date
    /// A short description for the activity feed: the tool and what it's working on ("Bash: swift test"), or the
    /// agent's notification text. Never the user's prompt.
    public var detail: String?
    /// The app and terminal tab the agent runs in, found by the helper. Older helpers don't send it.
    public var terminal: TerminalLocation?

    public init(agent: AgentKind, event: String, session: String, cwd: String?, time: Date, detail: String? = nil,
                terminal: TerminalLocation? = nil) {
        self.agent = agent
        self.event = event
        self.session = session
        self.cwd = cwd
        self.time = time
        self.detail = detail
        self.terminal = terminal
    }

    public var activity: AgentActivity? { agent.activity(forEvent: event) }

    /// Builds an event from what an agent wrote to a hook's stdin. Agents disagree on key names, so this looks for
    /// the session and folder under each known spelling. Falls back to a per-agent session when there's no ID.
    public static func fromHook(agent: AgentKind, event: String, stdin: Data, now: Date = Date()) -> AgentEvent {
        let payload = (try? JSONSerialization.jsonObject(with: stdin)) as? [String: Any] ?? [:]
        func string(_ keys: [String]) -> String? {
            for key in keys {
                if let value = payload[key] as? String, !value.isEmpty { return value }
                if let list = payload[key] as? [String], let first = list.first, !first.isEmpty { return first }
            }
            return nil
        }
        let session = string(["session_id", "sessionId", "conversation_id", "conversationId"]) ?? "\(agent.rawValue)-default"
        let cwd = string(["cwd", "workspace_roots", "workspaceRoot", "workspacePaths"])
        return AgentEvent(agent: agent, event: event, session: session, cwd: cwd, time: now, detail: detail(from: payload))
    }

    static let maxDetailLength = 140

    /// "Tool: what it's acting on", or the notification message.
    static func detail(from payload: [String: Any]) -> String? {
        let tool = (payload["tool_name"] ?? payload["toolName"]) as? String
            ?? (payload["toolCall"] as? [String: Any])?["name"] as? String
        let input = (payload["tool_input"] ?? payload["toolInput"]) as? [String: Any] ?? [:]
        let target = ["command", "file_path", "path", "pattern", "url", "query", "description"]
            .lazy.compactMap { input[$0] as? String }.first { !$0.isEmpty }
        var text: String?
        if let tool {
            text = target.map { "\(tool): \($0)" } ?? tool
        } else if let message = payload["message"] as? String, !message.isEmpty {
            text = message
        }
        guard var result = text?.replacingOccurrences(of: "\n", with: " ") else { return nil }
        if result.count > maxDetailLength { result = String(result.prefix(maxDetailLength - 1)) + "…" }
        return result
    }

    /// One line of the wire format.
    public func encodedLine() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self) + Data([0x0A])
    }

    /// The app's view of an event that came over the socket: stamped with the time it arrived (a client can't keep a
    /// session alive with a future date) and with every string capped, whoever sent it.
    public func received(at now: Date) -> AgentEvent {
        func cap(_ text: String, _ limit: Int) -> String {
            text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
        }
        var event = self
        event.time = now
        event.event = cap(event.event, 64)
        event.session = cap(event.session, 128)
        event.cwd = event.cwd.map { cap($0, 1024) }
        event.detail = event.detail.map { cap($0.replacingOccurrences(of: "\n", with: " "), Self.maxDetailLength) }
        event.terminal = event.terminal.map {
            TerminalLocation(appPaths: $0.appPaths.prefix(8).map { cap($0, 1024) }, tty: $0.tty.map { cap($0, 64) })
        }
        return event
    }

    public static func decode(line: Data) -> AgentEvent? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(AgentEvent.self, from: line)
    }
}
