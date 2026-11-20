import AppKit

/// Owns `AppState` and refuses to quit while BRB is up, so ⌘Q or a script can't take the away screen down.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
        // Lets a developer (or a test script) open BRB straight away: BRBUDDY_START_AWAY=1. Debug builds only.
        if let path = ProcessInfo.processInfo.environment["BRBUDDY_COMPANION_SHEET"] {
            CompanionContactSheet.render(to: URL(fileURLWithPath: path))
        }
        if ProcessInfo.processInfo.environment["BRBUDDY_START_AWAY"] == "1" {
            state.startAway()
            if let folder = ProcessInfo.processInfo.environment["BRBUDDY_SNAPSHOT_DIR"] {
                Task { await state.away.debugSnapshots(to: URL(fileURLWithPath: folder)) }
            }
        }
        #endif
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        state.away.isAway ? .terminateCancel : .terminateNow
    }
}
