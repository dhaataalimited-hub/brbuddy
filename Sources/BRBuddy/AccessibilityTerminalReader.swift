import AppKit
import ApplicationServices

/// Reads the text of a terminal window through the Accessibility API: read-only, plain text, no colours. Works with
/// Terminal, iTerm2 and Ghostty, which expose their screen as a text area. Needs the user to allow BRBuddy under
/// System Settings → Privacy & Security → Accessibility.
enum AccessibilityTerminalReader {
    static let terminalApps: [(bundleID: String, name: String)] = [
        ("com.apple.Terminal", "Terminal"), ("com.googlecode.iterm2", "iTerm2"), ("com.mitchellh.ghostty", "Ghostty"),
    ]

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows macOS's own prompt pointing the user to the Accessibility setting.
    static func requestTrust() {
        // The value of kAXTrustedCheckOptionPrompt (the global itself isn't concurrency-safe in Swift 6).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    struct Target: Sendable {
        var pid: pid_t
        var appName: String
    }

    /// Running terminal apps, most recently active first. Call on the main thread.
    @MainActor
    static func runningTerminals() -> [Target] {
        let running = NSWorkspace.shared.runningApplications
        return terminalApps.compactMap { app in
            running.first { $0.bundleIdentifier == app.bundleID }.map { Target(pid: $0.processIdentifier, appName: app.name) }
        }
    }

    struct Capture: Sendable {
        var source: String
        var text: String
    }

    /// The text of the best window: one whose title mentions `preferring`, else the app's main window, else its
    /// first. Keeps the last `lines` lines. Safe to call off the main thread.
    static func read(from targets: [Target], preferring hint: String?, lines: Int = 80) -> Capture? {
        for target in targets {
            let app = AXUIElementCreateApplication(target.pid)
            AXUIElementSetMessagingTimeout(app, 0.5)
            let windows = (attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
            let main = attribute(app, kAXMainWindowAttribute).map { $0 as! AXUIElement }
            let titled = windows.map { ($0, (attribute($0, kAXTitleAttribute) as? String) ?? "") }
            let chosen = hint.flatMap { hint in titled.first { $0.1.localizedCaseInsensitiveContains(hint) } }
                ?? main.map { m in (m, (attribute(m, kAXTitleAttribute) as? String) ?? "") }
                ?? titled.first
            guard let (window, title) = chosen, let text = textAreaValue(in: window) else { continue }
            let kept = text.components(separatedBy: "\n").reversed().drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
                .prefix(lines).reversed().joined(separator: "\n")
            return Capture(source: title.isEmpty ? target.appName : "\(target.appName) · \(title)", text: kept)
        }
        return nil
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    /// The value of the first text area under `element` (breadth-first, a few levels deep).
    private static func textAreaValue(in element: AXUIElement) -> String? {
        var queue: [(AXUIElement, Int)] = [(element, 0)]
        while !queue.isEmpty {
            let (node, depth) = queue.removeFirst()
            if (attribute(node, kAXRoleAttribute) as? String) == kAXTextAreaRole,
               let value = attribute(node, kAXValueAttribute) as? String {
                return value
            }
            guard depth < 6 else { continue }
            for child in (attribute(node, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { queue.append((child, depth + 1)) }
        }
        return nil
    }
}
