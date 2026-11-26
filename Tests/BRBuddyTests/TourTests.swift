import BRBuddyCore
import CoreGraphics
import Foundation
import Testing

struct FirstLaunchTourTests {
    typealias Step = FirstLaunchTour.Step

    @Test func stepsRunInOrderAndStopAtTheEnds() {
        #expect(Step.agents.next == .tryBRB)
        #expect(Step.extras.next == .done)
        #expect(Step.done.next == .done)
        #expect(Step.agents.previous == .agents)
        #expect(Step.companion.previous == .tryBRB)
        #expect(Step.agents.counter == "Step 1 of 4")
        #expect(Step.extras.counter == "Step 4 of 4")
        #expect(Step.done.counter == nil)
    }

    @Test func showsAtLaunchUntilSeen() throws {
        let store = try #require(UserDefaults(suiteName: "tour-tests-\(UUID().uuidString)"))
        #expect(FirstLaunchTour.shouldShowAtLaunch(store: store))
        FirstLaunchTour.markSeen(store: store)
        #expect(!FirstLaunchTour.shouldShowAtLaunch(store: store))
    }

    // A 1440 x 900 screen with a 25 pt menu bar.
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let size = CGSize(width: 200, height: 160)

    @Test func hangsUnderTheMenuBarItem() {
        let icon = CGRect(x: 1100, y: 875, width: 30, height: 25)
        let origin = FirstLaunchTour.origin(size: size, anchor: icon, visible: visible)
        #expect(origin == CGPoint(x: 1015, y: 715))
        // Further down, under something else that hangs there.
        #expect(FirstLaunchTour.origin(size: size, anchor: icon, visible: visible, below: 150).y == 565)
    }

    @Test func staysOnScreenNearTheRightEdge() {
        let icon = CGRect(x: 1420, y: 875, width: 20, height: 25)
        #expect(FirstLaunchTour.origin(size: size, anchor: icon, visible: visible).x == 1232)
    }

    @Test func goesToTheMiddleWithoutAnIconOnScreen() {
        let middle = FirstLaunchTour.origin(size: size, anchor: nil, visible: visible)
        #expect(middle.x == 620)
        #expect(middle.y + size.height <= visible.maxY)
        let offScreen = CGRect(x: -40, y: 875, width: 30, height: 25)
        #expect(FirstLaunchTour.origin(size: size, anchor: offScreen, visible: visible) == middle)
    }
}
