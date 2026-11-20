import Foundation

/// The rules for when BRB starts on its own and when it hands off to the real lock screen. Pure, so it's tested
/// without touching the system.
public enum AwayPolicy {
    /// Whether BRB should start by itself now.
    /// It only auto-starts while keep-awake is on (the stand-in for "an agent is working" until agent detection lands).
    public static func shouldAutoStart(idleSeconds: TimeInterval, keepAwakeOn: Bool, isAway: Bool,
                                       settings: AwaySettings) -> Bool {
        guard settings.autoStartEnabled, keepAwakeOn, !isAway else { return false }
        return idleSeconds >= TimeInterval(settings.idleMinutes * 60)
    }

    public enum Escalation: Equatable, Sendable {
        case none
        case tooManyFailedAttempts
        case awayTooLong
    }

    /// Whether BRB should hand off to the real macOS lock screen.
    public static func escalation(failedAttempts: Int, awayFor seconds: TimeInterval,
                                  settings: AwaySettings) -> Escalation {
        if failedAttempts >= settings.maxFailedAttempts { return .tooManyFailedAttempts }
        if settings.escalateAfterMinutes > 0, seconds >= TimeInterval(settings.escalateAfterMinutes * 60) {
            return .awayTooLong
        }
        return .none
    }
}
