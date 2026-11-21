import AppKit
import ApplicationServices
import BRBuddyCore

/// Takes the user to the window an agent session is running in, from the menu. Terminal and iTerm2 select the exact
/// tab by its terminal device (through AppleScript; macOS asks once to let BRBuddy control them). Other apps
/// (Ghostty, Cursor, VS Code…) are brought forward and, with Accessibility allowed, the window showing the
/// session's folder is raised.
enum TerminalFocuser {
    /// The running app hosting the session: the nearest of its ancestors' apps that's a regular (Dock) app.
    @MainActor
    static func hostApp(of session: AgentTracker.Session) -> NSRunningApplication? {
        guard let paths = session.terminal?.appPaths else { return nil }
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            if let app = regular.first(where: { $0.bundleURL?.standardizedFileURL == url }) { return app }
        }
        return nil
    }

    @MainActor
    static func focus(_ session: AgentTracker.Session) {
        guard let app = hostApp(of: session) else { return }
        let tty = session.terminal?.tty
        let script = tty == nil ? nil : app.bundleIdentifier.flatMap(selectTabScript(bundleID:))
        let pid = app.processIdentifier
        let cwd = session.cwd
        Task.detached(priority: .userInitiated) {
            if let script, let tty, runAppleScript(script, argument: tty) { return }
            await MainActor.run { bringForward(pid: pid, cwd: cwd) }
        }
    }

    /// Activates the app and, when the window for `cwd` can be found, raises it.
    @MainActor
    private static func bringForward(pid: pid_t, cwd: String?) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if AXIsProcessTrusted(), let cwd { raiseWindow(of: pid, showing: cwd) }
        app.activate()
    }

    /// Raises the window whose document is the folder (Ghostty and Terminal set it from the shell's directory), else
    /// one whose title names the folder (editors put the project in the title).
    private static func raiseWindow(of pid: pid_t, showing cwd: String) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }
        func string(_ window: AXUIElement, _ name: String) -> String? {
            var value: AnyObject?
            return AXUIElementCopyAttributeValue(window, name as CFString, &value) == .success ? value as? String : nil
        }
        let folder = URL(fileURLWithPath: cwd).standardizedFileURL.path
        let name = (cwd as NSString).lastPathComponent
        let match = windows.first { window in
            string(window, kAXDocumentAttribute).flatMap(URL.init(string:))?.standardizedFileURL.path == folder
        } ?? windows.first { string($0, kAXTitleAttribute)?.localizedCaseInsensitiveContains(name) == true }
        guard let match else { return }
        AXUIElementPerformAction(match, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(match, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    /// An AppleScript that selects the tab whose terminal is `argv's item 1` and returns "true", for apps that can.
    static func selectTabScript(bundleID: String) -> String? {
        switch bundleID {
        case "com.apple.Terminal":
            """
            on run argv
                set wanted to item 1 of argv
                tell application id "com.apple.Terminal"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if tty of t is wanted then
                                set selected of t to true
                                set index of w to 1
                                activate
                                return "true"
                            end if
                        end repeat
                    end repeat
                end tell
                return "false"
            end run
            """
        case "com.googlecode.iterm2":
            """
            on run argv
                set wanted to item 1 of argv
                tell application id "com.googlecode.iterm2"
                    repeat with w in windows
                        repeat with t in tabs of w
                            repeat with s in sessions of t
                                if tty of s is wanted then
                                    select w
                                    tell t to select
                                    tell s to select
                                    activate
                                    return "true"
                                end if
                            end repeat
                        end repeat
                    end repeat
                end tell
                return "false"
            end run
            """
        default:
            nil
        }
    }

    /// Runs a script with `osascript` (off the main thread: macOS may first ask the user for permission) and
    /// reports whether it printed "true".
    private static func runAppleScript(_ source: String, argument: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source, argument]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0
            && String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
}
