import BRBuddyCore
import Observation

/// The app's single source of truth for what BRBuddy is doing right now. Created once by `BRBuddyApp`.
@MainActor
@Observable
final class AppState {
    private let keepAwake = KeepAwake()

    private(set) var isKeepingAwake = false

    func setKeepingAwake(_ on: Bool) {
        if on {
            isKeepingAwake = keepAwake.activate(.systemOnly)
        } else {
            keepAwake.release()
            isKeepingAwake = false
        }
    }
}
