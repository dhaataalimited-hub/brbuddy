import Foundation

/// The user's BRB (Away mode) preferences, stored in UserDefaults.
public struct AwaySettings: Equatable, Sendable {
    /// Start BRB on its own after this long with no keyboard or mouse input, while keep-awake is on.
    public var autoStartEnabled: Bool
    public var idleMinutes: Int
    /// Hand off to the real macOS lock screen after this many failed unlock attempts.
    public var maxFailedAttempts: Int
    /// Hand off to the real macOS lock screen after BRB has been up this long. 0 means never.
    public var escalateAfterMinutes: Int
    /// Keep the Mac awake by itself while a hooked-up agent is working or waiting for the user.
    public var keepAwakeForAgents: Bool
    /// Show the battery (and let the companion react to it) on the away screen. Ignored on Macs without one.
    public var showBattery: Bool
    /// Play a sound when someone clicks (boops) the companion.
    public var boopSounds: Bool

    public static let defaults = AwaySettings(
        autoStartEnabled: true, idleMinutes: 3, maxFailedAttempts: 3, escalateAfterMinutes: 60,
        keepAwakeForAgents: true, showBattery: true, boopSounds: true)

    public init(autoStartEnabled: Bool, idleMinutes: Int, maxFailedAttempts: Int, escalateAfterMinutes: Int,
                keepAwakeForAgents: Bool = true, showBattery: Bool = true, boopSounds: Bool = true) {
        self.showBattery = showBattery
        self.boopSounds = boopSounds
        self.autoStartEnabled = autoStartEnabled
        self.idleMinutes = idleMinutes
        self.maxFailedAttempts = maxFailedAttempts
        self.escalateAfterMinutes = escalateAfterMinutes
        self.keepAwakeForAgents = keepAwakeForAgents
    }

    private enum Key {
        static let autoStart = "away.autoStartEnabled"
        static let idle = "away.idleMinutes"
        static let attempts = "away.maxFailedAttempts"
        static let escalate = "away.escalateAfterMinutes"
        static let agents = "agents.keepAwake"
        static let battery = "away.showBattery"
        static let boopSounds = "companion.boopSounds"
    }

    /// Reads settings, falling back to `defaults` for anything unset and clamping values to sane ranges.
    public static func load(from store: UserDefaults = .standard) -> AwaySettings {
        let d = defaults
        func int(_ key: String, _ fallback: Int, _ range: ClosedRange<Int>) -> Int {
            guard store.object(forKey: key) != nil else { return fallback }
            return min(max(store.integer(forKey: key), range.lowerBound), range.upperBound)
        }
        return AwaySettings(
            autoStartEnabled: store.object(forKey: Key.autoStart) == nil ? d.autoStartEnabled : store.bool(forKey: Key.autoStart),
            idleMinutes: int(Key.idle, d.idleMinutes, 1...120),
            maxFailedAttempts: int(Key.attempts, d.maxFailedAttempts, 1...10),
            escalateAfterMinutes: int(Key.escalate, d.escalateAfterMinutes, 0...24 * 60),
            keepAwakeForAgents: store.object(forKey: Key.agents) == nil ? d.keepAwakeForAgents : store.bool(forKey: Key.agents),
            showBattery: store.object(forKey: Key.battery) == nil ? d.showBattery : store.bool(forKey: Key.battery),
            boopSounds: store.object(forKey: Key.boopSounds) == nil ? d.boopSounds : store.bool(forKey: Key.boopSounds))
    }

    public func save(to store: UserDefaults = .standard) {
        store.set(autoStartEnabled, forKey: Key.autoStart)
        store.set(idleMinutes, forKey: Key.idle)
        store.set(maxFailedAttempts, forKey: Key.attempts)
        store.set(escalateAfterMinutes, forKey: Key.escalate)
        store.set(keepAwakeForAgents, forKey: Key.agents)
        store.set(showBattery, forKey: Key.battery)
        store.set(boopSounds, forKey: Key.boopSounds)
    }
}
