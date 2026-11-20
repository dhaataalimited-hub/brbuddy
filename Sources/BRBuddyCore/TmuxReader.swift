import Foundation

/// Reads tmux panes, read-only: lists panes and captures what one shows (with colours). Never sends keys, never
/// attaches a client, so it can't change sizes or type into anything.
public enum TmuxReader {
    public struct Pane: Equatable, Sendable {
        public var id: String
        public var command: String
        public var path: String
        public var label: String
        public var isActive: Bool

        /// The folder's name, for display.
        public var folderName: String { (path as NSString).lastPathComponent }
    }

    static let format = "#{pane_id}\t#{pane_current_command}\t#{pane_current_path}\t#{session_name}:#{window_index}.#{pane_index}\t#{?#{&&:#{pane_active},#{window_active}},1,0}"

    public static let searchPaths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]

    public static func executable() -> URL? {
        searchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }.map(URL.init(fileURLWithPath:))
    }

    public static func parsePanes(_ output: String) -> [Pane] {
        output.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0].hasPrefix("%") else { return nil }
            return Pane(id: f[0], command: f[1], path: f[2], label: f[3], isActive: f[4] == "1")
        }
    }

    /// The pane to mirror: one running an agent in the agent's folder, then any pane running an agent, then one in
    /// the agent's folder, then the active pane.
    public static func choosePane(_ panes: [Pane], agentFolder: String?) -> Pane? {
        let agentCommands = Set(["claude", "codex", "cursor-agent", "gemini", "agy", "grok", "node"])
        func runsAgent(_ p: Pane) -> Bool { agentCommands.contains(p.command) || p.command.first?.isNumber == true }
        func inFolder(_ p: Pane) -> Bool { agentFolder.map { p.path == $0 } ?? false }
        return panes.first { runsAgent($0) && inFolder($0) }
            ?? panes.first(where: runsAgent)
            ?? panes.first(where: inFolder)
            ?? panes.first(where: \.isActive)
            ?? panes.first
    }

    public static func listPanes(tmux: URL) -> [Pane] {
        guard let output = run(tmux, ["list-panes", "-a", "-F", format]) else { return [] }
        return parsePanes(output)
    }

    /// The visible contents of a pane, with colour codes.
    public static func capture(_ pane: Pane, tmux: URL) -> String? {
        run(tmux, ["capture-pane", "-p", "-e", "-t", pane.id])
    }

    /// Runs tmux with a 2-second limit; nil on failure (no server, no tmux).
    static func run(_ tmux: URL, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = tmux
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        final class Box: @unchecked Sendable { var data = Data() }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let handle = out.fileHandleForReading
        DispatchQueue.global(qos: .utility).async {
            box.data = handle.readDataToEndOfFile()
            done.signal()
        }
        if done.wait(timeout: .now() + 2) == .timedOut {
            process.terminate()
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: box.data, as: UTF8.self)
    }
}
