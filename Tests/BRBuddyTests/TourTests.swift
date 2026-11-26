import BRBuddyCore
import CoreGraphics
import Foundation
import Testing

struct FirstLaunchTourTests {
    typealias Step = FirstLaunchTour.Step

    @Test func stepsRunInOrderAndStopAtTheEnds() {
        #expect(Step.agents.next == .companion)
        #expect(Step.extras.next == .tryBRB)
        #expect(Step.tryBRB.next == .tryBRB)
        #expect(Step.agents.previous == .agents)
        #expect(Step.tryBRB.previous == .extras)
        #expect(Step.agents.counter == "Step 1 of 4")
        #expect(Step.tryBRB.counter == "Step 4 of 4")
        // Trying BRB ends the tour, so it has to be the last step.
        #expect(Step.tryBRB.isLast)
        #expect(!Step.extras.isLast)
    }

    @Test func showsAtLaunchUntilSeen() throws {
        let store = try #require(UserDefaults(suiteName: "tour-tests-\(UUID().uuidString)"))
        #expect(FirstLaunchTour.shouldShowAtLaunch(store: store))
        FirstLaunchTour.markSeen(store: store)
        #expect(!FirstLaunchTour.shouldShowAtLaunch(store: store))
    }

    @Test func hangsForFifteenSecondsBeforeClimbingAway() {
        #expect(FirstLaunchTour.hangSeconds == 15)
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

    // A 1512 x 982 MacBook screen with a notch from x 680 to 832 and a 37 pt menu bar.
    let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let notchLeft = CGRect(x: 0, y: 945, width: 680, height: 37)
    let notchRight = CGRect(x: 832, y: 945, width: 680, height: 37)

    @Test func seesAMenuBarItemBesideTheNotch() {
        let item = CGRect(x: 1100, y: 945, width: 30, height: 37)
        #expect(FirstLaunchTour.isVisible(item: item, screen: laptop, notchLeft: notchLeft, notchRight: notchRight))
        #expect(FirstLaunchTour.isVisible(item: item, screen: laptop))
    }

    @Test func treatsAnItemBehindTheNotchAsHidden() {
        let item = CGRect(x: 740, y: 945, width: 30, height: 37)
        #expect(!FirstLaunchTour.isVisible(item: item, screen: laptop, notchLeft: notchLeft, notchRight: notchRight))
    }

    @Test func treatsAnItemOffScreenOrBelowTheMenuBarAsHidden() {
        #expect(!FirstLaunchTour.isVisible(item: CGRect(x: -100, y: 945, width: 30, height: 37), screen: laptop))
        #expect(!FirstLaunchTour.isVisible(item: CGRect(x: 1100, y: 400, width: 30, height: 37), screen: laptop))
        #expect(!FirstLaunchTour.isVisible(item: CGRect(x: 1100, y: 945, width: 0, height: 37), screen: laptop))
    }

    @Test func handlesNotchAreasGivenRelativeToASecondScreen() {
        let screen = CGRect(x: 1920, y: 0, width: 1512, height: 982)
        let item = CGRect(x: 1920 + 740, y: 945, width: 30, height: 37)
        #expect(!FirstLaunchTour.isVisible(item: item, screen: screen, notchLeft: notchLeft, notchRight: notchRight))
        let beside = CGRect(x: 1920 + 1100, y: 945, width: 30, height: 37)
        #expect(FirstLaunchTour.isVisible(item: beside, screen: screen, notchLeft: notchLeft, notchRight: notchRight))
    }
}
