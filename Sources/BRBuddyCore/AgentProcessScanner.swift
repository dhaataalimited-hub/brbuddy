import Darwin
import Foundation

/// Finds agents that are running, whether or not their hooks are set up. Tells BRBuddy what's installed and in
/// use (so Settings can offer hook setup); it can't tell working from idle, which is what hooks are for.
public enum AgentProcessScanner {
    /// Command-line agents by process name.
    static let processNames: [String: AgentKind] = [
        "claude": .claude, "codex": .codex, "cursor-agent": .cursor,
        "gemini": .gemini, "agy": .antigravity, "grok": .grok,
    ]

    /// Desktop apps by bundle ID, with the name to show. The app layer checks these against running apps.
    public static let desktopApps: [String: String] = [
        "com.anthropic.claudefordesktop": "Claude",
        "com.openai.chat": "ChatGPT",
        "com.openai.codex": "ChatGPT / Codex",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.google.antigravity": "Antigravity",
    ]

    /// Which hook-able agents have a process running right now.
    public static func runningAgents() -> Set<AgentKind> {
        var found = Set<AgentKind>()
        for pid in allPIDs() {
            let name = processName(pid)
            if let kind = processNames[name] {
                found.insert(kind)
            } else if name == "node", arguments(pid).dropFirst().first.map(isGeminiScript) == true {
                found.insert(.gemini)  // Gemini CLI runs as a Node script.
            }
        }
        return found
    }

    static func isGeminiScript(_ path: String) -> Bool {
        path.hasSuffix("/gemini") || path.contains("gemini-cli")
    }

    static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return Array(pids.prefix(Int(max(filled, 0)))).filter { $0 > 0 }
    }

    static func processName(_ pid: pid_t) -> String {
        executablePath(pid).map { ($0 as NSString).lastPathComponent } ?? ""
    }

    /// The full path of a process's executable, or nil if it's gone or hidden from us.
    static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// A process's arguments (argv), read from the kernel. Empty if not allowed or gone.
    static func arguments(_ pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        // Layout: argc, executable path, padding NULs, then argc NUL-terminated arguments.
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        var args: [String] = []
        while args.count < Int(argc), index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            args.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return args
    }
}
