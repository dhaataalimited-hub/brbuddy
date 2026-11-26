import AppKit
import BRBuddyCore
import os

/// Where the app writes its log lines: macOS's unified log (`os.Logger`, subsystem com.dhaataalimited.brbuddy) for
/// Console, and `DiagnosticLog` on disk for **Send Logs…**. Callers never pass passwords, typed text, terminal or
/// mirror contents, notes, or project names and paths; `LogRedaction` is a second line of defence, not the first.
enum AppLog {
    private static let subsystem = "com.dhaataalimited.brbuddy"
    private static let loggers: [DiagnosticLog.Category: Logger] = Dictionary(
        uniqueKeysWithValues: DiagnosticLog.Category.allCases.map { ($0, Logger(subsystem: subsystem, category: $0.rawValue)) })

    static func info(_ category: DiagnosticLog.Category, _ message: String) {
        loggers[category]?.info("\(message, privacy: .public)")
        DiagnosticLog.shared.write(category, message)
    }

    static func error(_ category: DiagnosticLog.Category, _ message: String) {
        loggers[category]?.error("\(message, privacy: .public)")
        DiagnosticLog.shared.write(category, "ERROR: \(message)")
    }

    /// "x 120, y 840, 230 × 196" for a frame in screen points.
    static func describe(_ rect: CGRect?) -> String {
        guard let rect else { return "none" }
        return "x \(Int(rect.minX)), y \(Int(rect.minY)), \(Int(rect.width)) × \(Int(rect.height))"
    }

    // MARK: About this Mac

    /// The report's header: BRBuddy's version, macOS, the Mac model and its screens. Nothing that names the user.
    @MainActor
    static func header(state: AppState) -> [(String, String)] {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let screens = NSScreen.screens.enumerated().map { index, screen in
            let notch = screen.auxiliaryTopLeftArea != nil ? ", notch" : ""
            return "\(index + 1): \(Int(screen.frame.width)) × \(Int(screen.frame.height)) at \(Int(screen.frame.minX)), \(Int(screen.frame.minY))\(notch)"
        }
        return [
            ("BRBuddy", AppVersion.label()),
            ("macOS", "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"),
            ("Mac", "\(sysctl("hw.model")) (\(sysctl("hw.machine")))"),
            ("Screens", screens.joined(separator: "; ")),
            ("Appearance", NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? "dark" : "light"),
            ("Agents connected", state.agents.hooksInstalled.map(\.displayName).sorted().joined(separator: ", ").ifEmpty("none")),
            ("Keep awake for agents", state.settings.keepAwakeForAgents ? "on" : "off"),
            ("BRB auto-start", state.settings.autoStartEnabled ? "after \(state.settings.idleMinutes) min" : "off"),
            ("Walk-away", state.proximity.settings.isActive ? "on" : "off"),
            ("Open at login", state.launchesAtLogin ? (state.launchAtLoginNeedsApproval ? "waiting for approval" : "on") : "off"),
        ]
    }

    private static func sysctl(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: value)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
