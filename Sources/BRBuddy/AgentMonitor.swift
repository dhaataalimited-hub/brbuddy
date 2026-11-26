import AppKit
import BRBuddyCore
import Observation

/// Knows what the user's AI agents are doing: receives hook events on the local socket, keeps an `AgentTracker`,
/// spots running agents and desktop apps, and sets hooks up or removes them on request. Owned by `AppState`.
@MainActor
@Observable
final class AgentMonitor {
    private(set) var tracker = AgentTracker()
    /// What agents did, for the terminal mirror's activity feed.
    private(set) var activity = AgentActivityLog()
    private(set) var runningAgents: Set<AgentKind> = []
    private(set) var runningDesktopApps: [String] = []
    private(set) var hooksInstalled: Set<AgentKind> = []
    private(set) var setupErrors: [AgentKind: String] = [:]
    private(set) var listenerError: String?
    /// The agent that sent the most recent event, kept after its session is forgotten.
    private(set) var lastAgent: AgentKind?

    /// Called whenever the overall summary may have changed.
    var onChange: (() -> Void)?
    /// The last activity written to the log for each session, so the log only records changes.
    @ObservationIgnored private var loggedActivity: [String: AgentActivity] = [:]

    private let listener = AgentEventListener()
    private var timer: Timer?
    let installer: AgentHookInstaller

    var summary: AgentTracker.Summary { tracker.summary }

    /// The agent the companion should match: the one in the summary, else the latest session, else the last seen.
    var relevantAgent: AgentKind? {
        switch summary {
        case .waiting(let s), .working(let s), .finished(let s): s.agent
        case .none: tracker.orderedSessions.first?.agent ?? lastAgent
        }
    }

    /// Where the hook helper lives for agents to run: a stable path that survives moving the app.
    static let helperURL = AgentSocket.supportFolder.appending(path: "bin/\(AgentHookInstaller.helperName)")

    init() {
        installer = AgentHookInstaller(helperPath: Self.helperURL.path)
        copyHelperIntoPlace()
        do {
            try listener.start { [weak self] event in
                Task { @MainActor in self?.receive(event) }
            }
        } catch {
            listenerError = "BRBuddy couldn't listen for agents: \(error.localizedDescription)"
            AppLog.error(.agents, listenerError ?? "")
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func receive(_ event: AgentEvent) {
        // Only when a session's activity changes (not every tool call), and only the agent and what happened: no
        // folder, prompt, detail or session id.
        if let activity = event.activity, loggedActivity[event.session] != activity {
            loggedActivity[event.session] = activity
            AppLog.info(.agents, "\(event.agent.displayName): \(event.event) → \(activity)")
        }
        tracker.apply(event)
        activity.record(event)
        lastAgent = event.agent
        runningAgents.insert(event.agent)
        onChange?()
    }

    /// Prunes quiet sessions and rescans processes, apps and hook files.
    func refresh() {
        tracker.prune(now: Date())
        hooksInstalled = Set(AgentKind.allCases.filter(installer.isInstalled))
        let bundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        runningDesktopApps = AgentProcessScanner.desktopApps.filter { bundleIDs.contains($0.key) }.map(\.value).sorted()
        Task.detached(priority: .utility) {
            let running = AgentProcessScanner.runningAgents()
            await MainActor.run { [weak self] in self?.runningAgents = running }
        }
        onChange?()
    }

    // MARK: Hook setup

    func setUpHooks(for agent: AgentKind) {
        do {
            try installer.install(agent)
            setupErrors[agent] = nil
            AppLog.info(.agents, "Connected \(agent.displayName)")
        } catch {
            setupErrors[agent] = error.localizedDescription
            AppLog.error(.agents, "Connecting \(agent.displayName) failed: \(error.localizedDescription)")
        }
        refresh()
    }

    func removeHooks(for agent: AgentKind) {
        do {
            try installer.uninstall(agent)
            setupErrors[agent] = nil
            AppLog.info(.agents, "Disconnected \(agent.displayName)")
        } catch {
            setupErrors[agent] = error.localizedDescription
            AppLog.error(.agents, "Disconnecting \(agent.displayName) failed: \(error.localizedDescription)")
        }
        refresh()
    }

    /// Whether this Mac has the agent (its settings folder exists or it's running).
    func isPresent(_ agent: AgentKind) -> Bool {
        installer.agentFolderExists(agent) || runningAgents.contains(agent)
    }

    /// Copies the helper from the app bundle (or next to the executable, for `swift run`) to `helperURL`, so hook
    /// commands keep working if the app is moved or updated.
    private func copyHelperIntoPlace() {
        let candidates = [
            Bundle.main.bundleURL.appending(path: "Contents/Helpers/\(AgentHookInstaller.helperName)"),
            Bundle.main.executableURL?.deletingLastPathComponent().appending(path: AgentHookInstaller.helperName),
        ].compactMap { $0 }
        let fm = FileManager.default
        guard let source = candidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) else { return }
        let target = Self.helperURL
        if let new = try? Data(contentsOf: source), let old = try? Data(contentsOf: target), new == old { return }
        do {
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: source, to: target)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        } catch {
            listenerError = "BRBuddy couldn't install its hook helper: \(error.localizedDescription)"
            AppLog.error(.agents, listenerError ?? "")
        }
    }
}

extension AgentTracker.Summary {
    /// One line for the menu and the away screen, or nil when there's nothing to say.
    var headline: String? {
        switch self {
        case .waiting(let s): "\(s.agent.displayName) needs you\(s.projectName.map { " in \($0)" } ?? "")"
        case .working(let s): "\(s.agent.displayName) is working\(s.projectName.map { " on \($0)" } ?? "")"
        case .finished(let s): "\(s.agent.displayName) finished\(s.projectName.map { " \($0)" } ?? "")"
        case .none: nil
        }
    }

    var needsAttention: Bool {
        if case .waiting = self { true } else { false }
    }
}
