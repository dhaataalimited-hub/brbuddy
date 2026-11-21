import Darwin
import Foundation

/// Where an agent session is running, so BRBuddy can take the user straight to it: the apps among its process's
/// ancestors (Terminal, iTerm2, Ghostty, Cursor, VS Code…) and the terminal device of its tab. Found by
/// `brbuddy-hook`, whose ancestry leads from the agent through the shell up to the terminal app.
public struct TerminalLocation: Codable, Equatable, Sendable {
    /// App bundles of the hook's ancestors, nearest first, e.g. ["/Applications/iTerm.app"]. Some are only
    /// wrappers (Xcode's Python.app, an editor's helper app); the app keeps the first that's a running regular app.
    public var appPaths: [String]
    /// The controlling terminal, e.g. "/dev/ttys003". Terminal and iTerm2 can select the tab that owns it.
    public var tty: String?

    public init(appPaths: [String], tty: String?) {
        self.appPaths = appPaths
        self.tty = tty
    }

    /// The app bundle whose executable this is (".../Ghostty.app/Contents/MacOS/ghostty" → ".../Ghostty.app"), or nil
    /// for a plain command-line tool, even one stored inside a bundle.
    public static func appBundle(ofExecutable path: String) -> String? {
        guard let range = path.range(of: ".app/Contents/MacOS/", options: .backwards) else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    /// Walks up from this process's parent to launchd. Nil when there's neither an app nor a terminal (a detached
    /// tmux server, a remote shell).
    public static func current() -> TerminalLocation? {
        var tty: String?
        var apps: [String] = []
        var pid = getppid()
        for _ in 0..<32 where pid > 1 {
            guard let info = processInfo(pid) else { break }
            if tty == nil { tty = deviceName(info.tdev) }
            if let app = AgentProcessScanner.executablePath(pid).flatMap(appBundle(ofExecutable:)), !apps.contains(app) {
                apps.append(app)
            }
            pid = info.ppid
        }
        return apps.isEmpty && tty == nil ? nil : TerminalLocation(appPaths: apps, tty: tty)
    }

    /// Parent and controlling terminal from the kernel. Works for processes of other users (login runs as root).
    static func processInfo(_ pid: pid_t) -> (ppid: pid_t, tdev: dev_t)? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return (info.kp_eproc.e_ppid, info.kp_eproc.e_tdev)
    }

    static func deviceName(_ dev: dev_t) -> String? {
        guard dev != -1, dev != 0, let name = devname(dev, S_IFCHR) else { return nil }
        let text = String(cString: name)
        return text.isEmpty || text == "??" ? nil : "/dev/\(text)"
    }
}
