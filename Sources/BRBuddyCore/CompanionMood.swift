import Foundation

/// How the companion on the away screen should act right now.
public enum CompanionMood: String, CaseIterable, Sendable {
    /// Nobody around and no agent busy: snoozing.
    case resting
    /// An agent is working.
    case working
    /// An agent needs the user.
    case waiting
    /// An agent just finished.
    case finished
    /// Someone touched the Mac: saying hello while they unlock.
    case greeting
    /// A failed unlock, or handing off to the real lock screen.
    case oops

    /// Picks the mood. Away-screen events (someone at the Mac, a failure) win over what the agent is doing.
    public static func current(isUnlocking: Bool, recentFailure: Bool, lockingForReal: Bool,
                               agent: AgentTracker.Summary) -> CompanionMood {
        if lockingForReal || recentFailure { return .oops }
        if isUnlocking { return .greeting }
        switch agent {
        case .waiting: return .waiting
        case .working: return .working
        case .finished: return .finished
        case .none: return .resting
        }
    }

    /// The Codex pet spritesheet row that plays this mood (rows: 0 idle, 3 waving, 4 jumping, 5 failed, 6 waiting,
    /// 7 running).
    public var codexRow: Int {
        switch self {
        case .resting: 0
        case .working: 7
        case .waiting: 6
        case .finished: 4
        case .greeting: 3
        case .oops: 5
        }
    }
}
