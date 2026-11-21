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

/// A walk-away dry run in Settings, to check the chosen device is really the user's phone or watch and the range
/// suits the room: hold it close (the signal should jump), walk away (BRBuddy should notice), come back. BRB doesn't
/// start while a test runs. Pure: fed each reading by `ProximityMonitor`.
public struct WalkAwayTest: Equatable, Sendable {
    /// Signal (dBm, smoothed) that counts as "right next to the Mac".
    public static let closeSignal: Double = -50

    public private(set) var sawClose = false
    public private(set) var sawAway = false
    public private(set) var sawBack = false

    public init() {}

    public var isComplete: Bool { sawClose && sawAway && sawBack }

    public mutating func observe(smoothed: Double?, state: ProximityTracker.State) {
        if let smoothed, smoothed >= Self.closeSignal { sawClose = true }
        if state == .away { sawAway = true }
        if sawAway, state == .near { sawBack = true }
    }
}

/// Keeps track of the user's iPhone across Bluetooth address changes. iPhones switch to a new random address about
/// every 15 minutes, and macOS gives each address its own identifier, so a chosen device "disappears" while still on
/// the desk. When the watched identifier goes quiet and a brand-new Apple device shows up at about the same signal
/// strength, that's almost certainly the same phone under its new address, so the watcher should switch to it. If
/// nothing similar shows up, the phone really left and `ProximityTracker` reports it away. Pure: time is passed in.
public struct AddressFollower: Sendable {
    /// How long the watched identifier must be quiet before a successor is considered.
    public var quietFor: TimeInterval = 4
    /// A successor's smoothed signal must be within this many dB of the phone's last level.
    public var tolerance: Double = 10
    /// With no level to compare (the saved identifier was stale from the start), only a device held this close counts.
    public var closeLevel: Double = -50
    /// Readings needed before a successor is trusted.
    public var readingsNeeded = 3

    private var firstSeen: [UUID: Date] = [:]
    private var candidates: [UUID: (level: Double, count: Int)] = [:]

    public init() {}

    public mutating func reset() {
        firstSeen = [:]
        candidates = [:]
    }

    /// Feeds one advertisement from an Apple phone/watch-type device that isn't the watched one. Returns its
    /// identifier when it should become the watched device.
    /// - Parameters:
    ///   - watchedLastHeard: last reading from the watched identifier (advertisement or connected signal read), nil if
    ///     never heard since watching began.
    ///   - watchedLastAdvertised: last advertisement from it. While connected the phone can switch its advertising
    ///     address and keep the link, so "new" means new since the old address last advertised.
    ///   - watchedLevel: the watched device's smoothed signal at that time.
    ///   - watchingSince: when watching began.
    public mutating func heard(_ id: UUID, rssi: Double, at now: Date, watchedLastHeard: Date?,
                               watchedLastAdvertised: Date? = nil, watchedLevel: Double?, watchingSince: Date) -> UUID? {
        firstSeen[id] = firstSeen[id] ?? now
        let previous = candidates[id]
        let level = previous.map { $0.level * 0.6 + rssi * 0.4 } ?? rssi
        candidates[id] = (level, (previous?.count ?? 0) + 1)

        let quietSince = watchedLastHeard ?? watchingSince
        guard now.timeIntervalSince(quietSince) >= quietFor else { return nil }
        // A new address, not a device that was already around while the phone was still being heard.
        let advertisedUntil = watchedLastAdvertised ?? watchedLastHeard ?? watchingSince
        guard let first = firstSeen[id], first >= advertisedUntil.addingTimeInterval(-2) else { return nil }
        guard let candidate = candidates[id], candidate.count >= readingsNeeded else { return nil }
        if let watchedLevel {
            guard abs(candidate.level - watchedLevel) <= tolerance else { return nil }
        } else {
            guard candidate.level >= closeLevel else { return nil }
        }
        return id
    }
}
