@testable import BRBuddyCore
import Foundation
import Testing

struct ProximityTrackerTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    @Test func becomesNearThenAwayAfterStayingWeak() {
        var tracker = ProximityTracker(range: .room)  // threshold -74
        #expect(tracker.add(rssi: -50, at: at(0)) == .near)
        // Walks away: weak readings every 2 s.
        for s in stride(from: 2.0, through: 10, by: 2) { tracker.add(rssi: -88, at: at(s)) }
        #expect(tracker.state == .near)  // weak, but not for 10 s yet (median only turned weak at ~6 s)
        var left: ProximityTracker.State?
        for s in stride(from: 12.0, through: 20, by: 2) { left = tracker.add(rssi: -88, at: at(s)) ?? left }
        #expect(left == .away && tracker.state == .away)
    }

    @Test func ignoresBriefDipsAndBadReadings() {
        var tracker = ProximityTracker(range: .room)
        tracker.add(rssi: -50, at: at(0))
        tracker.add(rssi: -95, at: at(2))  // one bad reading: the median stays strong
        tracker.add(rssi: -52, at: at(4))
        tracker.add(rssi: 127, at: at(5))  // "unavailable"
        for s in stride(from: 6.0, through: 30, by: 2) { tracker.add(rssi: -55, at: at(s)) }
        #expect(tracker.state == .near)
    }

    @Test func goesAwayWhenSilentAndComesBackOnlyWhenClearlyStronger() {
        var tracker = ProximityTracker(range: .room)
        tracker.add(rssi: -60, at: at(0))
        #expect(tracker.tick(now: at(59)) == nil)
        #expect(tracker.tick(now: at(60)) == .away)
        // Back at the edge of range: not enough (needs -74 + 6 = -68).
        tracker.add(rssi: -72, at: at(70))
        #expect(tracker.state == .away)
        #expect(tracker.add(rssi: -60, at: at(80)) == .near)
    }

    @Test func rangesAreOrderedAndResetForgets() {
        #expect(ProximityTracker.Range.near.threshold > ProximityTracker.Range.room.threshold)
        #expect(ProximityTracker.Range.room.threshold > ProximityTracker.Range.far.threshold)
        var tracker = ProximityTracker(range: .near)
        tracker.add(rssi: -40, at: at(0))
        tracker.reset()
        #expect(tracker.state == .unknown && tracker.smoothed == nil)
        #expect(tracker.tick(now: at(500)) == nil)  // no device heard since reset: stays unknown
    }

    @Test func settingsRoundTrip() throws {
        let store = try #require(UserDefaults(suiteName: "brbuddy.tests.\(UUID().uuidString)"))
        #expect(ProximitySettings.load(from: store) == ProximitySettings())
        #expect(!ProximitySettings().isActive)
        var s = ProximitySettings()
        s.enabled = true; s.deviceID = "ABC"; s.deviceName = "Phone"; s.range = .near; s.action = .lockMac
        s.save(to: store)
        #expect(ProximitySettings.load(from: store) == s)
        #expect(s.isActive)
    }
}
