import AppKit
import BRBuddyCore
import Observation

/// Produces the read-only terminal view for the away screen: a tmux pane, a terminal window read through
/// Accessibility, or the agent activity feed, depending on the user's `TerminalMirrorMode`. Refreshes once a second
/// while BRB is up or the Settings preview is open. Owned by `AppState`.
@MainActor
@Observable
final class TerminalMirror {
    struct Snapshot: Equatable {
        var source: String
        var lines: [TerminalLine]
    }

    var mode: TerminalMirrorMode {
        didSet {
            mode.save()
            refresh()
        }
    }

    private(set) var snapshot: Snapshot?
    /// Why there's nothing to show, when there isn't.
    private(set) var status: String?

    var agents: AgentMonitor?

    private var users = 0
    private var timer: Timer?
    private var refreshing = false

    init() {
        mode = TerminalMirrorMode.load()
    }

    var isEnabled: Bool { mode != .off }
    var tmuxInstalled: Bool { TmuxReader.executable() != nil }

    /// Starts refreshing (BRB came up, or the Settings preview opened). Balanced by `release`.
    func retain() {
        users += 1
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func release() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        timer?.invalidate()
        timer = nil
        snapshot = nil
    }

    func refresh() {
        guard mode != .off else { snapshot = nil; status = nil; return }
        guard !refreshing else { return }
        refreshing = true
        let mode = mode
        let folder = agentFolder
        let terminals = AccessibilityTerminalReader.runningTerminals()
        let trusted = AccessibilityTerminalReader.isTrusted
        let feed = feedSnapshot()
        Task.detached(priority: .utility) {
            let result = Self.capture(mode: mode, agentFolder: folder, terminals: terminals, trusted: trusted, feed: feed)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.refreshing = false
                self.snapshot = result.snapshot
                self.status = result.status
            }
        }
    }

    private var agentFolder: String? {
        switch agents?.summary ?? .none {
        case .waiting(let s), .working(let s), .finished(let s): s.cwd
        case .none: agents?.tracker.orderedSessions.first?.cwd
        }
    }

    private func feedSnapshot() -> Snapshot? {
        guard let log = agents?.activity, !log.entries.isEmpty else { return nil }
        return Snapshot(source: "Agent activity", lines: log.terminalLines())
    }

    /// Tries the sources the mode allows, in order. Runs off the main thread.
    nonisolated private static func capture(mode: TerminalMirrorMode, agentFolder: String?,
                                            terminals: [AccessibilityTerminalReader.Target], trusted: Bool,
                                            feed: Snapshot?) -> (snapshot: Snapshot?, status: String?) {
        var reasons: [String] = []
        if mode == .automatic || mode == .tmux {
            if let tmux = TmuxReader.executable() {
                if let pane = TmuxReader.choosePane(TmuxReader.listPanes(tmux: tmux), agentFolder: agentFolder),
                   let text = TmuxReader.capture(pane, tmux: tmux) {
                    return (Snapshot(source: "tmux \(pane.label) · \(pane.folderName)", lines: ANSIParser.parse(text)), nil)
                }
                reasons.append("no tmux session is running")
            } else {
                reasons.append("tmux isn't installed")
            }
        }
        if mode == .automatic || mode == .terminalWindow {
            if !trusted {
                reasons.append("BRBuddy isn't allowed to read terminal windows (Accessibility)")
            } else if terminals.isEmpty {
                reasons.append("no Terminal, iTerm2 or Ghostty window is open")
            } else if let capture = AccessibilityTerminalReader.read(from: terminals,
                                                                     preferring: agentFolder.map { ($0 as NSString).lastPathComponent }) {
                return (Snapshot(source: capture.source, lines: ANSIParser.plain(capture.text)), nil)
            } else {
                reasons.append("couldn't read the terminal window")
            }
        }
        if mode == .automatic || mode == .activityFeed {
            if let feed { return (feed, nil) }
            reasons.append("no agent activity yet (set up an agent's hooks in Settings)")
        }
        return (nil, "Nothing to show: " + reasons.joined(separator: "; ") + ".")
    }
}
