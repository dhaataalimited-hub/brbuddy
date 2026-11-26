import AppKit

/// Owns `AppState` and the first-launch tour (`TourController`), and refuses to quit while BRB is up, so ⌘Q or a script can't take the away screen down.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let updates = UpdateController()
    private(set) lazy var tour = TourController(state: state)

    func applicationDidFinishLaunching(_: Notification) {
        tour.showAtLaunchIfNew()
        #if DEBUG
        // Lets a developer (or a test script) open BRB straight away: BRBUDDY_START_AWAY=1. Debug builds only.
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_COMPANION_SHEET"] {
            CompanionContactSheet.render(to: URL(fileURLWithPath: path))
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_MOUTH_SHEET"] {
            CompanionContactSheet.renderMouths(to: URL(fileURLWithPath: path))
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_STUDIO_SNAPSHOT"] {
            Task { await CompanionContactSheet.renderStudio(library: state.companions, to: URL(fileURLWithPath: path)) }
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_BOOP_SHEET"] {
            CompanionContactSheet.renderBoops(to: URL(fileURLWithPath: path))
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_ICON_OPTIONS"] {
            CompanionContactSheet.renderIconOptions(to: URL(fileURLWithPath: path))
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_BATTERY_SHEET"] {
            CompanionContactSheet.renderBattery(to: URL(fileURLWithPath: path))
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_SITE_ART"] {
            CompanionContactSheet.renderSiteArt(to: URL(fileURLWithPath: path))
        }
        // BRBUDDY_PROMO=<dir>: render the promo film's frames and sounds (Tools/promo/make-promo.sh), then quit.
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_PROMO"] {
            PromoFilm.render(to: URL(fileURLWithPath: path))
            exit(0)
        }
        // BRBUDDY_TOUR=1: show the first-launch tour even if it has been seen.
        if ProcessInfo.processInfo.environment["BRBUDDY_TOUR"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if !tour.isOpen { tour.show() }
            }
        }
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_TOUR_SNAPSHOTS"] {
            Task { await tour.debugSnapshots(to: URL(fileURLWithPath: path)) }
        }
        // BRBUDDY_START_AWAY=<seconds>: open BRB that many seconds after launch (1 = almost straight away).
        if let delay = ProcessInfo.processInfo.environment["BRBUDDY_START_AWAY"].flatMap(Double.init), delay > 0 {
            Task {
                try? await Task.sleep(for: .seconds(delay))
                state.startAway()
                if let folder = ProcessInfo.processInfo.environment["BRBUDDY_SNAPSHOT_DIR"] {
                    await state.away.debugSnapshots(to: URL(fileURLWithPath: folder))
                }
            }
        }
        #endif
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        state.away.isAway ? .terminateCancel : .terminateNow
    }
}
