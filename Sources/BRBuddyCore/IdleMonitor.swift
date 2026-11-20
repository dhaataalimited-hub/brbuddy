import CoreGraphics
import Foundation

/// How long since the last keyboard, mouse or trackpad input, as macOS's hardware input system counts it.
///
/// Uses the HID system state rather than the session state, so it reflects input that reached the hardware event
/// layer. Known gap: software that posts events at the HID level (some remote-desktop tools, mouse jigglers) still
/// resets it. Telling real from posted input needs a listen-only event tap; see ROADMAP.md.
public enum IdleMonitor {
    public static func secondsSinceLastInput() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
    }
}
