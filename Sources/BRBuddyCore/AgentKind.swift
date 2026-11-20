import Foundation

/// The AI coding agents BRBuddy can hook into, and how each one's lifecycle events map to what BRBuddy cares about.
///
/// Event names and config locations follow AgentPet (MIT); see THIRD_PARTY_NOTICES.md.
public enum AgentKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case claude, codex, gemini, cursor, antigravity, grok

    public var id: String { rawValue }

    /// Shown in the menu, Settings and on the away screen. Agents are named, never their logos.
    public var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .gemini: "Gemini CLI"
        case .cursor: "Cursor"
        case .antigravity: "Antigravity"
        case .grok: "Grok"
        }
    }

    /// The events BRBuddy registers hooks for. Blocking gates (a hook that can deny a tool) are left out where an
    /// agent treats a failing hook as "deny", so BRBuddy can never stop an agent's work.
    public var hookEvents: [String] {
        switch self {
        case .claude: ["SessionStart", "UserPromptSubmit", "PreToolUse", "Notification", "Stop", "SessionEnd"]
        case .codex: ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "Stop"]
        case .gemini: ["SessionStart", "BeforeAgent", "BeforeTool", "AfterTool", "Notification", "AfterAgent", "SessionEnd"]
        case .cursor: ["sessionStart", "beforeSubmitPrompt", "preToolUse", "stop", "sessionEnd"]
        case .antigravity: ["PreInvocation", "PreToolUse", "PostToolUse", "Stop"]
        case .grok: ["SessionStart", "UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd"]
        }
    }

    /// What an event means. `nil` for events that don't change anything.
    public func activity(forEvent event: String) -> AgentActivity? {
        switch (self, event) {
        case (_, "SessionStart"), (.cursor, "sessionStart"):
            return .started
        case (_, "SessionEnd"), (.cursor, "sessionEnd"):
            return .ended
        case (_, "UserPromptSubmit"), (_, "PreToolUse"), (_, "PostToolUse"),
             (.gemini, "BeforeAgent"), (.gemini, "BeforeTool"), (.gemini, "AfterTool"),
             (.cursor, "beforeSubmitPrompt"), (.cursor, "preToolUse"),
             (.antigravity, "PreInvocation"):
            return .working
        case (_, "Notification"), (.codex, "PermissionRequest"):
            return .waiting
        case (_, "Stop"), (.gemini, "AfterAgent"), (.cursor, "stop"):
            return .finished
        default:
            return nil
        }
    }
}

/// What an agent session is doing, independent of which agent it is.
public enum AgentActivity: String, Codable, Sendable {
    /// Session opened, nothing asked of it yet.
    case started
    /// Working on a prompt: thinking or running tools.
    case working
    /// Blocked on the user: a question or a permission prompt.
    case waiting
    /// Finished its turn.
    case finished
    /// Session closed.
    case ended
}
