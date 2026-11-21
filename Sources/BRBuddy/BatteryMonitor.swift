import BRBuddyCore
import Foundation
import Observation

/// Reads the battery every second while the away screen is up, and notices plugging in and unplugging so the badge
/// and companion can react. Owned by `AppState`; does nothing on a Mac without a battery.
@MainActor
@Observable
final class BatteryMonitor {
    private(set) var watch = BatteryWatch()

    var status: BatteryStatus? { watch.status }
    var reaction: BatteryReaction { watch.reaction(now: now) }

    /// Moves every reading, so `reaction` lets a flourish expire on time.
    private var now = Date()
    private var users = 0
    private var timer: Timer?

    /// Starts reading (BRB came up). Balanced by `release`.
    func retain() {
        users += 1
        guard timer == nil else { return }
        watch = BatteryWatch()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func release() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        now = Date()
        watch.update(Self.reading(), now: now)
    }

    private static func reading() -> BatteryStatus? {
        #if DEBUG
        if let fake = fakeReading() { return fake }
        #endif
        return BatteryStatus.read()
    }

    #if DEBUG
    private static let launched = Date()

    /// Debug builds only: BRBUDDY_FAKE_BATTERY="15;15,charging;100,plugged;60,lowpower" steps through fake readings,
    /// one every BRBUDDY_FAKE_BATTERY_STEP seconds (default 4), then stays on the last.
    private static func fakeReading() -> BatteryStatus? {
        let environment = ProcessInfo.processInfo.environment
        guard let list = environment["BRBUDDY_FAKE_BATTERY"] else { return nil }
        let steps = list.split(separator: ";")
        guard !steps.isEmpty else { return nil }
        let step = environment["BRBUDDY_FAKE_BATTERY_STEP"].flatMap(Double.init) ?? 4
        let index = min(Int(Date().timeIntervalSince(launched) / step), steps.count - 1)
        let parts = steps[index].split(separator: ",").map(String.init)
        let percent = Int(parts[0]) ?? 50
        let flags = Set(parts.dropFirst())
        let charging = flags.contains("charging")
        return BatteryStatus(percent: percent, isPluggedIn: charging || flags.contains("plugged"), isCharging: charging,
                             isLowPowerMode: flags.contains("lowpower"), minutesRemaining: percent < 100 ? 83 : nil)
    }
    #endif
}
