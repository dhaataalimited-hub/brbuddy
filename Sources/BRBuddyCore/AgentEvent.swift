import Foundation

/// One hook firing, as `brbuddy-hook` sends it to the app: one JSON object per line over the local socket.
public struct AgentEvent: Codable, Equatable, Sendable {
    public var agent: AgentKind
    public var event: String
    public var session: String
    /// The project folder the agent is working in, if the agent said.
    public var cwd: String?
    public var time: Date

    public init(agent: AgentKind, event: String, session: String, cwd: String?, time: Date) {
        self.agent = agent
        self.event = event
        self.session = session
        self.cwd = cwd
        self.time = time
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
        return AgentEvent(agent: agent, event: event, session: session, cwd: cwd, time: now)
    }

    /// One line of the wire format.
    public func encodedLine() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self) + Data([0x0A])
    }

    public static func decode(line: Data) -> AgentEvent? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(AgentEvent.self, from: line)
    }
}
