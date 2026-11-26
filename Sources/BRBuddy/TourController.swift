import AppKit
import BRBuddyCore
import Observation
import SwiftUI

/// Runs the first-launch tour (`FirstLaunchTour`): the companion hanging under the menu bar icon, and the tour panel
/// under it. Created by `AppDelegate`; opens by itself on first launch and from **Show tour again** in the menu.
@MainActor
@Observable
final class TourController {
    let state: AppState
    let windows: AppWindows
    /// Where the paw is right now (`StatusItemController`), or nil when it can't be seen.
    private let findPlace: () -> (anchor: CGRect?, visible: CGRect)
    private(set) var step: FirstLaunchTour.Step = .agents
    /// What the hanging companion says, if anything.
    private(set) var bubble: String?
    /// Whether the tour panel is open (the companion stops talking while it is).
    private(set) var isTouring = false
    /// Set while the companion climbs back up to the menu bar before the tour closes.
    private(set) var isLeaving = false

    private var buddyPanel: NSPanel?
    private var tourPanel: NSPanel?
    private var closeObserver: NSObjectProtocol?
    /// Where the companion hangs, worked out when the tour opens, so both panels line up with the same paw.
    private var place: (anchor: CGRect?, visible: CGRect)?

    static let buddySize = CGSize(width: 230, height: 196)
    static let tourSize = CGSize(width: 400, height: 360)

    init(state: AppState, windows: AppWindows, place: @escaping () -> (anchor: CGRect?, visible: CGRect)) {
        self.state = state
        self.windows = windows
        self.findPlace = place
    }

    var isOpen: Bool { buddyPanel != nil }

    /// Opens at launch the first time only. Waits a moment so the menu bar item has its place.
    func showAtLaunchIfNew() {
        guard FirstLaunchTour.shouldShowAtLaunch() else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            show()
        }
    }

    /// Hangs the companion under the menu bar icon, inviting a click.
    func show() {
        guard !state.away.isAway else { return }
        step = .agents
        isTouring = false
        isLeaving = false
        bubble = "Hi! I live up here in your menu bar. Click me for a quick tour."
        place = findPlace()
        showBuddy()
    }

    /// Opens the tour panel (clicking the hanging companion does this).
    func startTour() {
        isTouring = true
        bubble = nil
        state.agents.refresh()
        showTourPanel()
    }

    func go(to next: FirstLaunchTour.Step) { step = next }

    /// The tour's last step: ends the tour, then covers the screen for real so the user sees BRB and how to come
    /// back. Nothing reopens afterwards, so the panels never have to find the paw again.
    func tryBRB() {
        FirstLaunchTour.markSeen()
        closeAll()
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            state.startAway()
        }
    }

    /// Ends the tour for good: the companion says goodbye and climbs back up to the menu bar.
    func finish() {
        FirstLaunchTour.markSeen()
        removeCloseObserver()
        tourPanel?.orderOut(nil)
        tourPanel = nil
        isTouring = false
        bubble = "See you up there!"
        isLeaving = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            closeAll()
        }
    }

    #if DEBUG
    /// Saves the hanging companion and every tour step as PNGs into `folder`. `BRBUDDY_TOUR_SNAPSHOTS=<dir>`.
    func debugSnapshots(to folder: URL) async {
        func save(_ panel: NSPanel?, _ name: String) {
            guard let view = panel?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: "\(name).png"))
        }
        show()
        try? await Task.sleep(for: .seconds(1))
        save(buddyPanel, "0-hanging")
        startTour()
        for next in FirstLaunchTour.Step.allCases {
            go(to: next)
            try? await Task.sleep(for: .seconds(0.8))
            save(tourPanel, "\(next.rawValue + 1)-\(next)")
        }
        save(buddyPanel, "6-hanging-during-tour")
        closeAll()
    }
    #endif

    // MARK: Panels

    private func showBuddy() {
        let panel = buddyPanel ?? makeBuddyPanel()
        buddyPanel = panel
        let (anchor, visible) = place ?? findPlace()
        panel.setFrameOrigin(FirstLaunchTour.origin(size: Self.buddySize, anchor: anchor, visible: visible))
        panel.orderFrontRegardless()
    }

    private func showTourPanel() {
        let panel = tourPanel ?? makeTourPanel()
        tourPanel = panel
        let (anchor, visible) = place ?? findPlace()
        // Under the hanging companion, its string and feet; the tour reads as something it's holding up.
        panel.setFrameOrigin(FirstLaunchTour.origin(size: Self.tourSize, anchor: anchor, visible: visible,
                                                    below: Self.buddySize.height - 92))
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func closeAll() {
        removeCloseObserver()
        tourPanel?.orderOut(nil)
        buddyPanel?.orderOut(nil)
        tourPanel = nil
        buddyPanel = nil
        isTouring = false
        isLeaving = false
        bubble = nil
        place = nil
    }

    private func removeCloseObserver() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
    }

    private func makeBuddyPanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.buddySize),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: HangingBuddyView(tour: self))
        return panel
    }

    private func makeTourPanel() -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.tourSize),
                            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: TourView(tour: self))
        // The close button skips the rest of the tour.
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel,
                                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.tourPanel != nil else { return }
                self.tourPanel = nil
                self.finish()
            }
        }
        return panel
    }
}
