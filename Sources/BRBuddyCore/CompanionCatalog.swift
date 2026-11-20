import Foundation

/// BRBuddy's built-in companions and how the user's choice is stored and resolved.
///
/// Built-ins are original characters drawn in code. Each one nods to an agent's vibe through colour and personality,
/// never its logo or mascot.
public enum CompanionCatalog {
    public struct BuiltIn: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let blurb: String
        /// The agent it's matched to when the user picks "Match my agent".
        public let agent: AgentKind
    }

    public static let builtIns: [BuiltIn] = [
        BuiltIn(id: "ember", name: "Ember", blurb: "A warm, round little bear who naps on the job", agent: .claude),
        BuiltIn(id: "pebble", name: "Pebble", blurb: "Calm, smooth, unbothered. Has a sprout", agent: .codex),
        BuiltIn(id: "prism", name: "Prism", blurb: "Sharp-eared and quick, glows when busy", agent: .cursor),
        BuiltIn(id: "comet", name: "Comet", blurb: "Deep-space blue with star freckles", agent: .gemini),
        BuiltIn(id: "drift", name: "Drift", blurb: "A cloud that never quite touches the ground", agent: .antigravity),
        BuiltIn(id: "gremlin", name: "Gremlin", blurb: "Spiky, lopsided, chaotic grin", agent: .grok),
    ]

    public static let defaultBuiltIn = builtIns[0]

    public static func builtIn(id: String) -> BuiltIn? { builtIns.first { $0.id == id } }

    public static func builtIn(for agent: AgentKind) -> BuiltIn {
        builtIns.first { $0.agent == agent } ?? defaultBuiltIn
    }

    /// What the user picked in Settings. Stored as a string: "auto", "builtin:<id>" or "pack:<folder name>".
    public enum Choice: Equatable, Hashable, Sendable {
        case matchAgent
        case builtIn(String)
        case pack(String)

        public var storageValue: String {
            switch self {
            case .matchAgent: "auto"
            case .builtIn(let id): "builtin:\(id)"
            case .pack(let id): "pack:\(id)"
            }
        }

        public init(storageValue: String?) {
            guard let value = storageValue else { self = .matchAgent; return }
            if value.hasPrefix("builtin:") { self = .builtIn(String(value.dropFirst(8))) }
            else if value.hasPrefix("pack:") { self = .pack(String(value.dropFirst(5))) }
            else { self = .matchAgent }
        }

        static let key = "companion.choice"

        public static func load(from store: UserDefaults = .standard) -> Choice {
            Choice(storageValue: store.string(forKey: key))
        }

        public func save(to store: UserDefaults = .standard) {
            store.set(storageValue, forKey: Self.key)
        }
    }

    /// What to show. "Match my agent" uses the active agent's built-in, else the last agent seen, else Ember.
    /// A pack that's gone (deleted, invalid) falls back the same way. Packs that list agents are preferred over
    /// built-ins when matching.
    public enum Resolved: Equatable, Sendable {
        case builtIn(BuiltIn)
        case pack(String)
    }

    public static func resolve(_ choice: Choice, agent: AgentKind?, availablePacks: [String: [AgentKind]]) -> Resolved {
        switch choice {
        case .builtIn(let id):
            if let found = builtIn(id: id) { return .builtIn(found) }
        case .pack(let id):
            if availablePacks[id] != nil { return .pack(id) }
        case .matchAgent:
            break
        }
        guard let agent else { return .builtIn(defaultBuiltIn) }
        if let pack = availablePacks.filter({ $0.value.contains(agent) }).keys.sorted().first { return .pack(pack) }
        return .builtIn(builtIn(for: agent))
    }
}
