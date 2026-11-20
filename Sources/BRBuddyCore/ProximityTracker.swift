import Foundation

/// Decides from Bluetooth signal strength (RSSI) whether the user's phone or watch is near or has gone. Pure: samples
/// and times are passed in, so it's tested without Bluetooth.
///
/// Signal strength jumps around (bodies, pockets, walls), so it uses the median of the last few seconds and only
/// calls the device "away" after it has stayed weak for a while, or vanished. Coming back needs a clearly stronger
/// signal than leaving (hysteresis), so standing at the edge doesn't flicker. Design informed by BLEUnlock
/// (unlicensed, studied only; no code copied).
public struct ProximityTracker: Sendable {
    public enum Range: String, CaseIterable, Sendable, Identifiable {
        /// About arm's length: walking away from the desk.
        case near
        /// About the size of a room.
        case room
        /// Further: only leaving the area counts.
        case far

        public var id: String { rawValue }

        /// The RSSI below which the device counts as gone. Typical iPhone readings: -40 on the desk, -60 a few
        /// metres away, -80 or less in another room.
        public var threshold: Double {
            switch self {
            case .near: -62
            case .room: -74
            case .far: -86
            }
        }

        public var title: String {
            switch self {
            case .near: "Near (walk away from the desk)"
            case .room: "Room (leave the room)"
            case .far: "Far (leave the area)"
            }
        }
    }

    public enum State: Equatable, Sendable {
        case unknown
        case near
        case away
    }

    public var range: Range
    /// How long the signal must stay weak before the device counts as away.
    public var weakFor: TimeInterval = 10
    /// How long without any reading before the device counts as away.
    public var silentFor: TimeInterval = 60
    /// How much stronger than the threshold the signal must be to count as back.
    public var hysteresis: Double = 6
    /// Readings older than this are dropped from the median.
    public var window: TimeInterval = 8

    public private(set) var state: State = .unknown
    public private(set) var samples: [(time: Date, rssi: Double)] = []
    private var weakSince: Date?

    public init(range: Range) {
        self.range = range
    }

    /// The median of recent readings, or nil with none.
    public var smoothed: Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.map(\.rssi).sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    public var lastReading: Date? { samples.last?.time }

    /// Adds a reading. Returns the new state if it changed. Ignores impossible values (CoreBluetooth reports 127
    /// for "unavailable").
    @discardableResult
    public mutating func add(rssi: Double, at time: Date) -> State? {
        guard rssi < 0, rssi > -127 else { return nil }
        samples.append((time, rssi))
        samples.removeAll { time.timeIntervalSince($0.time) > window }
        return evaluate(now: time)
    }

    /// Checks for a device that's gone quiet. Call every second or so. Returns the new state if it changed.
    @discardableResult
    public mutating func tick(now: Date) -> State? {
        samples.removeAll { now.timeIntervalSince($0.time) > window }
        return evaluate(now: now)
    }

    /// Forgets everything (new device picked, or monitoring restarted).
    public mutating func reset() {
        state = .unknown
        samples = []
        weakSince = nil
        lastHeard = nil
    }

    private var lastHeard: Date?

    private mutating func evaluate(now: Date) -> State? {
        let old = state
        if let last = samples.last?.time { lastHeard = max(lastHeard ?? last, last) }

        if let heard = lastHeard, now.timeIntervalSince(heard) >= silentFor {
            state = .away
        } else if let level = smoothed {
            switch state {
            case .unknown:
                state = level >= range.threshold ? .near : .unknown
                if level < range.threshold { weakSince = weakSince ?? now }
                if let since = weakSince, now.timeIntervalSince(since) >= weakFor { state = .away }
            case .near:
                if level < range.threshold {
                    weakSince = weakSince ?? now
                    if let since = weakSince, now.timeIntervalSince(since) >= weakFor { state = .away }
                } else {
                    weakSince = nil
                }
            case .away:
                if level >= range.threshold + hysteresis {
                    state = .near
                    weakSince = nil
                }
            }
        }
        return state == old ? nil : state
    }
}

/// The user's walk-away lock preferences, stored in UserDefaults.
public struct ProximitySettings: Equatable, Sendable {
    public enum Action: String, CaseIterable, Sendable, Identifiable {
        /// Cover the screen with BRB (agent keeps going, companion shows).
        case startBRB
        /// Go straight to the real macOS lock screen.
        case lockMac

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .startBRB: "Start BRB"
            case .lockMac: "Lock the Mac"
            }
        }
    }

    public var enabled = false
    /// CoreBluetooth's identifier for the chosen device.
    public var deviceID: String?
    public var deviceName: String?
    public var range: ProximityTracker.Range = .room
    public var action: Action = .startBRB

    public init() {}

    enum Key {
        static let enabled = "proximity.enabled", device = "proximity.deviceID", name = "proximity.deviceName"
        static let range = "proximity.range", action = "proximity.action"
    }

    public static func load(from store: UserDefaults = .standard) -> ProximitySettings {
        var s = ProximitySettings()
        s.enabled = store.bool(forKey: Key.enabled)
        s.deviceID = store.string(forKey: Key.device)
        s.deviceName = store.string(forKey: Key.name)
        s.range = store.string(forKey: Key.range).flatMap(ProximityTracker.Range.init(rawValue:)) ?? .room
        s.action = store.string(forKey: Key.action).flatMap(Action.init(rawValue:)) ?? .startBRB
        return s
    }

    public func save(to store: UserDefaults = .standard) {
        store.set(enabled, forKey: Key.enabled)
        store.set(deviceID, forKey: Key.device)
        store.set(deviceName, forKey: Key.name)
        store.set(range.rawValue, forKey: Key.range)
        store.set(action.rawValue, forKey: Key.action)
    }

    /// Ready to watch a device.
    public var isActive: Bool { enabled && deviceID != nil }
}
