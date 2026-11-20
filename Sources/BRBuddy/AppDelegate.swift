import AppKit

/// Owns `AppState` and refuses to quit while BRB is up, so ⌘Q or a script can't take the away screen down.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let updates = UpdateController()

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
        // Lets a developer (or a test script) open BRB straight away: BRBUDDY_START_AWAY=1. Debug builds only.
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_COMPANION_SHEET"] {
            CompanionContactSheet.render(to: URL(fileURLWithPath: path))
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
