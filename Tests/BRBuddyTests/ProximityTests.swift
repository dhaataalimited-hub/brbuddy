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

struct AppleDeviceInfoTests {
    @Test func readsContinuityMessageTypes() {
        // Apple company ID, then Nearby Info (0x10, 5 bytes) and Handoff (0x0C, 2 bytes).
        let phone = Data([0x4C, 0x00, 0x10, 0x05, 1, 2, 3, 4, 5, 0x0C, 0x02, 9, 9])
        #expect(AppleDeviceInfo.messageTypes(manufacturerData: phone) == [0x10, 0x0C])
        #expect(AppleDeviceInfo.isPersonalDevice(manufacturerData: phone))
    }

    @Test func skipsAccessoriesAndOtherMakers() {
        let airpods = Data([0x4C, 0x00, 0x07, 0x03, 1, 2, 3])
        let airtag = Data([0x4C, 0x00, 0x12, 0x02, 0, 0])
        let other = Data([0x06, 0x00, 0x10, 0x01, 0])
        #expect(!AppleDeviceInfo.isPersonalDevice(manufacturerData: airpods))
        #expect(!AppleDeviceInfo.isPersonalDevice(manufacturerData: airtag))
        #expect(!AppleDeviceInfo.isPersonalDevice(manufacturerData: other))
        #expect(AppleDeviceInfo.messageTypes(manufacturerData: Data([0x4C])) == nil)
        // A length running past the end stops cleanly.
        #expect(AppleDeviceInfo.messageTypes(manufacturerData: Data([0x4C, 0x00, 0x10, 0xFF, 1])) == [0x10])
    }

    @Test func classifiesModelNumbers() {
        #expect(AppleDeviceInfo.kind(model: "iPhone15,2") == .iPhone)
        #expect(AppleDeviceInfo.kind(model: "Watch6,1") == .watch)
        #expect(AppleDeviceInfo.kind(model: "MacBookPro18,3") == .mac)
        #expect(AppleDeviceInfo.kind(model: "iPad13,1") == .iPad)
        #expect(AppleDeviceInfo.kind(model: "AppleTV14,1") == .other)
        #expect(AppleDeviceInfo.Kind.iPhone.isCarried && !AppleDeviceInfo.Kind.mac.isCarried)
    }
}

struct WalkAwayTestTests {
    @Test func ticksOffCloseAwayAndBackInOrder() {
        var test = WalkAwayTest()
        test.observe(smoothed: -70, state: .near)
        #expect(!test.sawClose && !test.sawAway)
        test.observe(smoothed: -42, state: .near)
        #expect(test.sawClose)
        test.observe(smoothed: -50, state: .near)
        #expect(!test.sawBack)  // being near before going away doesn't count as coming back
        test.observe(smoothed: -90, state: .away)
        #expect(test.sawAway && !test.isComplete)
        test.observe(smoothed: -60, state: .near)
        #expect(test.sawBack && test.isComplete)
    }

    @Test func noReadingsMeansNothingTicks() {
        var test = WalkAwayTest()
        test.observe(smoothed: nil, state: .unknown)
        #expect(test == WalkAwayTest())
    }
}


struct AddressFollowerTests {
    let start = Date(timeIntervalSince1970: 1000)

    @Test func followsANewAddressAtTheSameStrengthAfterTheOldOneGoesQuiet() {
        var follower = AddressFollower()
        let old = start.addingTimeInterval(10), new = UUID()
        var adopted: UUID?
        for second in 11...16 {
            adopted = follower.heard(new, rssi: -45, at: start.addingTimeInterval(Double(second)),
                                     watchedLastHeard: old, watchedLevel: -44, watchingSince: start) ?? adopted
        }
        #expect(adopted == new)
    }

    @Test func ignoresDevicesThatWereAlreadyAroundOrTooDifferent() {
        var follower = AddressFollower()
        let neighbour = UUID(), stranger = UUID()
        // The neighbour's phone was advertising before ours went quiet.
        _ = follower.heard(neighbour, rssi: -45, at: start.addingTimeInterval(1), watchedLastHeard: start.addingTimeInterval(1),
                           watchedLevel: -44, watchingSince: start)
        var adopted: UUID?
        for second in 20...30 {
            let now = start.addingTimeInterval(Double(second))
            for (id, rssi) in [(neighbour, -45.0), (stranger, -80.0)] {
                adopted = follower.heard(id, rssi: rssi, at: now, watchedLastHeard: start.addingTimeInterval(10),
                                         watchedLevel: -44, watchingSince: start) ?? adopted
            }
        }
        #expect(adopted == nil)
    }

    @Test func waitsUntilTheWatchedDeviceIsQuiet() {
        var follower = AddressFollower()
        let new = UUID()
        var adopted: UUID?
        for second in 1...5 {
            let now = start.addingTimeInterval(Double(second))
            adopted = follower.heard(new, rssi: -45, at: now, watchedLastHeard: now, watchedLevel: -45, watchingSince: start) ?? adopted
        }
        #expect(adopted == nil)
    }

    @Test func aStaleSavedDeviceIsReplacedOnlyByOneHeldClose() {
        var follower = AddressFollower()
        let far = UUID(), close = UUID()
        var adopted: UUID?
        for second in 5...10 {
            let now = start.addingTimeInterval(Double(second))
            adopted = follower.heard(far, rssi: -70, at: now, watchedLastHeard: nil, watchedLevel: nil, watchingSince: start) ?? adopted
            adopted = follower.heard(close, rssi: -38, at: now, watchedLastHeard: nil, watchedLevel: nil, watchingSince: start) ?? adopted
        }
        #expect(adopted == close)
    }
}

extension AddressFollowerTests {
    @Test func followsAnAddressChangeThatHappenedWhileConnected() {
        var follower = AddressFollower()
        let new = UUID()
        let advertisedUntil = start.addingTimeInterval(5)  // old address stopped advertising at 5 s
        var adopted: UUID?
        // The new address appears at 6 s while the link still gives readings until 30 s, then the link drops.
        for second in 6...40 {
            let now = start.addingTimeInterval(Double(second))
            let lastHeard = start.addingTimeInterval(Double(min(second, 30)))
            adopted = follower.heard(new, rssi: -46, at: now, watchedLastHeard: lastHeard,
                                     watchedLastAdvertised: advertisedUntil, watchedLevel: -45, watchingSince: start) ?? adopted
            if adopted != nil {
                #expect(second >= 34)  // only once the link has been quiet for 4 s
                break
            }
        }
        #expect(adopted == new)
    }
}

extension AddressFollowerTests {
    @Test func doesNotFollowWhileThePhoneWasFadingAway() {
        var follower = AddressFollower()
        let stranger = UUID()
        var adopted: UUID?
        // Our phone was last heard at -82 (leaving the room, below the Room threshold of -74); a new phone appears
        // at a similar weak level.
        for second in 15...30 {
            adopted = follower.heard(stranger, rssi: -80, at: start.addingTimeInterval(Double(second)),
                                     watchedLastHeard: start.addingTimeInterval(10), watchedLevel: -82, nearLevel: -74,
                                     watchingSince: start) ?? adopted
        }
        #expect(adopted == nil)
    }
}
