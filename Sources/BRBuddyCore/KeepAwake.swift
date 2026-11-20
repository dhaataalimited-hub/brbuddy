import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac from going to sleep while it's on, using a power-management assertion.
///
/// The system releases the assertion if the app quits or crashes, so the Mac can never get stuck awake.
/// Approach follows KeepingYouAwake (MIT); see THIRD_PARTY_NOTICES.md.
public final class KeepAwake {
    public enum Mode: Sendable, Equatable {
        /// The Mac stays awake but the screen may turn off. Enough for agents to keep running.
        case systemOnly
        /// The Mac and the screen both stay on. Used while the away screen is showing.
        case systemAndDisplay
    }

    public private(set) var mode: Mode?
    private var assertionID: IOPMAssertionID = 0

    public init() {}

    deinit { release() }

    public var isActive: Bool { mode != nil }

    /// Starts keeping the Mac awake in `mode`, replacing any earlier mode. Returns false if macOS refused.
    @discardableResult
    public func activate(_ mode: Mode, reason: String = "BRBuddy is keeping your Mac awake") -> Bool {
        release()
        let type = mode == .systemOnly
            ? kIOPMAssertionTypePreventUserIdleSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &id)
        guard result == kIOReturnSuccess else { return false }
        assertionID = id
        self.mode = mode
        return true
    }

    /// Lets the Mac sleep normally again.
    public func release() {
        guard mode != nil else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        mode = nil
    }
}
