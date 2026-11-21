import Foundation
import IOKit.ps

/// The Mac's internal battery, read from IOKit's power sources. `nil` from `read()` means no battery (a desktop Mac).
public struct BatteryStatus: Equatable, Sendable {
    /// 0–100.
    public var percent: Int
    /// On the charger (charging, or full and holding).
    public var isPluggedIn: Bool
    /// Actually taking charge right now.
    public var isCharging: Bool
    /// macOS Low Power Mode is on.
    public var isLowPowerMode: Bool
    /// Minutes until full while charging, or until empty on battery. `nil` while macOS is still working it out.
    public var minutesRemaining: Int?

    public init(percent: Int, isPluggedIn: Bool, isCharging: Bool, isLowPowerMode: Bool = false, minutesRemaining: Int? = nil) {
        self.percent = min(max(percent, 0), 100)
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.isLowPowerMode = isLowPowerMode
        self.minutesRemaining = minutesRemaining
    }

    /// At or below this, on battery, the battery is low.
    public static let lowPercent = 20
    /// At or below this, on battery, it's urgent.
    public static let criticalPercent = 10

    public var isLow: Bool { !isPluggedIn && percent <= Self.lowPercent }
    public var isCritical: Bool { !isPluggedIn && percent <= Self.criticalPercent }
    public var isFull: Bool { isPluggedIn && (percent >= 100 || (!isCharging && percent >= 95)) }

    /// Reads the internal battery now. Cheap enough to call every second.
    public static func read() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let status = parse(description, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
            else { continue }
            return status
        }
        return nil
    }

    /// Turns one IOKit power-source description into a status. `nil` for anything but a present internal battery
    /// (a UPS, say).
    public static func parse(_ description: [String: Any], lowPowerMode: Bool) -> BatteryStatus? {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              description[kIOPSIsPresentKey] as? Bool ?? true,
              let current = description[kIOPSCurrentCapacityKey] as? Int else { return nil }
        let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
        let pluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let charging = description[kIOPSIsChargingKey] as? Bool ?? false
        // -1 means "still calculating"; 0 to full means it's done.
        let minutesKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
        let minutes = (description[minutesKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
        return BatteryStatus(percent: percent, isPluggedIn: pluggedIn, isCharging: charging, isLowPowerMode: lowPowerMode,
                             minutesRemaining: pluggedIn && !charging ? nil : minutes)
    }
}

/// How the away screen reacts to the battery: the badge's look and what the companion does about it.
public enum BatteryReaction: Equatable, Sendable {
    /// Nothing to say (on battery with plenty left, or no battery).
    case none
    /// Just plugged in: a few seconds of celebrating.
    case pluggedIn
    /// Just unplugged: a few seconds of surprise.
    case unplugged
    case charging
    case full
    case lowPower
    case low
    case critical

    /// How long the plugged-in and unplugged reactions last.
    public static let flourishSeconds: TimeInterval = 6

    /// Picks the reaction. A fresh plug or unplug wins for a few seconds; then critical, low, Low Power Mode,
    /// charging, full.
    public static func current(_ status: BatteryStatus?, lastChange: BatteryWatch.Change?, now: Date = Date()) -> BatteryReaction {
        guard let status else { return .none }
        if let lastChange, now.timeIntervalSince(lastChange.at) < flourishSeconds {
            return lastChange.pluggedIn ? .pluggedIn : .unplugged
        }
        if status.isCritical { return .critical }
        if status.isLow { return .low }
        if status.isLowPowerMode { return .lowPower }
        if status.isFull { return .full }
        if status.isPluggedIn { return .charging }
        return .none
    }

    /// What the companion says about it, if anything.
    public var bubble: String? {
        switch self {
        case .none, .charging, .full, .lowPower: nil
        case .pluggedIn: "yum!"
        case .unplugged: "hey!"
        case .low: "snack?"
        case .critical: "plug me in!"
        }
    }

    /// The companion's mood while a flourish plays; `nil` keeps whatever the agent and away screen want.
    public var moodOverride: CompanionMood? {
        switch self {
        case .pluggedIn: .finished
        case .unplugged: .oops
        default: nil
        }
    }
}

/// Remembers the last battery reading so a plug or unplug can be noticed.
public struct BatteryWatch: Equatable, Sendable {
    public struct Change: Equatable, Sendable {
        public var pluggedIn: Bool
        public var at: Date
    }

    public private(set) var status: BatteryStatus?
    public private(set) var lastChange: Change?

    public init() {}

    /// Takes a new reading. The first reading never counts as a change.
    public mutating func update(_ new: BatteryStatus?, now: Date = Date()) {
        if let old = status, let new, old.isPluggedIn != new.isPluggedIn {
            lastChange = Change(pluggedIn: new.isPluggedIn, at: now)
        }
        status = new
    }

    public func reaction(now: Date = Date()) -> BatteryReaction {
        BatteryReaction.current(status, lastChange: lastChange, now: now)
    }
}
