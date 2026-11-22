@testable import BRBuddyCore
import Foundation
import Testing

struct AgentEventTests {
    @Test func mapsEachAgentsEventsToActivity() {
        #expect(AgentKind.claude.activity(forEvent: "UserPromptSubmit") == .working)
        #expect(AgentKind.claude.activity(forEvent: "Notification") == .waiting)
        #expect(AgentKind.claude.activity(forEvent: "Stop") == .finished)
        #expect(AgentKind.claude.activity(forEvent: "SessionEnd") == .ended)
        #expect(AgentKind.codex.activity(forEvent: "PermissionRequest") == .waiting)
        #expect(AgentKind.gemini.activity(forEvent: "AfterAgent") == .finished)
        #expect(AgentKind.cursor.activity(forEvent: "beforeSubmitPrompt") == .working)
        #expect(AgentKind.cursor.activity(forEvent: "stop") == .finished)
        #expect(AgentKind.antigravity.activity(forEvent: "PreInvocation") == .working)
        #expect(AgentKind.grok.activity(forEvent: "PostToolUse") == .working)
        #expect(AgentKind.claude.activity(forEvent: "SomethingNew") == nil)
        // Every registered hook event means something.
        for agent in AgentKind.allCases {
            for event in agent.hookEvents { #expect(agent.activity(forEvent: event) != nil, "\(agent) \(event)") }
        }
    }

    @Test func readsSessionAndFolderFromEachPayloadShape() {
        let claude = AgentEvent.fromHook(agent: .claude, event: "Stop",
                                         stdin: Data(#"{"session_id":"s1","cwd":"/p/app"}"#.utf8))
        #expect(claude.session == "s1" && claude.cwd == "/p/app")
        let cursor = AgentEvent.fromHook(agent: .cursor, event: "stop",
                                         stdin: Data(#"{"conversation_id":"c1","workspace_roots":["/p/web"]}"#.utf8))
        #expect(cursor.session == "c1" && cursor.cwd == "/p/web")
        let grok = AgentEvent.fromHook(agent: .grok, event: "Stop", stdin: Data(#"{"sessionId":"g1","workspaceRoot":"/g"}"#.utf8))
        #expect(grok.session == "g1" && grok.cwd == "/g")
        let empty = AgentEvent.fromHook(agent: .antigravity, event: "Stop", stdin: Data())
        #expect(empty.session == "antigravity-default" && empty.cwd == nil)
    }

    @Test func wireFormatRoundTrips() throws {
        let event = AgentEvent(agent: .codex, event: "Stop", session: "x", cwd: "/a", time: Date(timeIntervalSince1970: 100))
        #expect(AgentEvent.decode(line: try event.encodedLine().dropLast()) == event)
    }
}

struct AgentTrackerTests {
    func event(_ agent: AgentKind, _ name: String, _ session: String, at seconds: TimeInterval) -> AgentEvent {
        AgentEvent(agent: agent, event: name, session: session, cwd: "/p/\(session)", time: Date(timeIntervalSince1970: seconds))
    }

    @Test func summarisesMostUrgentFirst() {
        var tracker = AgentTracker()
        #expect(tracker.summary == .none)
        tracker.apply(event(.claude, "UserPromptSubmit", "a", at: 0))
        guard case .working(let s) = tracker.summary else { Issue.record("expected working"); return }
        #expect(s.projectName == "a")
        tracker.apply(event(.codex, "PermissionRequest", "b", at: 5))
        #expect({ if case .waiting = tracker.summary { true } else { false } }())
        #expect(tracker.summary.isActive)
        tracker.apply(event(.codex, "Stop", "b", at: 6))
        tracker.apply(event(.claude, "Stop", "a", at: 7))
        #expect({ if case .finished = tracker.summary { true } else { false } }())
        #expect(!tracker.summary.isActive)
        tracker.apply(event(.claude, "SessionEnd", "a", at: 8))
        #expect(tracker.sessions.count == 1)
    }

    @Test func forgetsQuietSessions() {
        var tracker = AgentTracker()
        tracker.apply(event(.claude, "PreToolUse", "a", at: 0))
        tracker.apply(event(.gemini, "AfterAgent", "b", at: 0))
        tracker.prune(now: Date(timeIntervalSince1970: AgentTracker.finishedTimeout + 1))
        #expect(tracker.sessions.count == 1)  // the finished one went first
        tracker.prune(now: Date(timeIntervalSince1970: AgentTracker.workingTimeout + 1))
        #expect(tracker.summary == .none)
    }
}

struct AgentHookInstallerTests {
    let installer = AgentHookInstaller(home: URL(fileURLWithPath: "/nonexistent"), helperPath: "/opt/brb/brbuddy-hook")

    @Test func nestedInstallKeepsOtherHooksAndIsIdempotent() {
        let foreign: [String: Any] = ["model": "x", "hooks": ["Stop": [["hooks": [["type": "command", "command": "say done"]]]]]]
        let once = installer.installed(into: foreign, agent: .claude)
        let twice = installer.installed(into: once, agent: .claude)
        #expect(NSDictionary(dictionary: once) == NSDictionary(dictionary: twice))
        #expect(installer.isInstalled(in: once, agent: .claude))
        let stop = (once["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]
        #expect(stop?.count == 2)
        let removed = installer.uninstalled(from: once, agent: .claude)
        #expect(NSDictionary(dictionary: removed) == NSDictionary(dictionary: foreign))
        #expect(!installer.isInstalled(in: removed, agent: .claude))
    }

    @Test func cursorAndAntigravityShapes() {
        let cursor = installer.installed(into: [:], agent: .cursor)
        #expect(cursor["version"] as? Int == 1)
        let item = ((cursor["hooks"] as? [String: Any])?["stop"] as? [[String: Any]])?.first
        #expect((item?["command"] as? String)?.contains("--agent cursor --event stop") == true)

        let anti = installer.installed(into: ["other": ["Stop": []]], agent: .antigravity)
        let group = anti["brbuddy"] as? [String: Any]
        #expect((group?["PreToolUse"] as? [[String: Any]])?.first?["matcher"] as? String == "*")
        #expect((group?["Stop"] as? [[String: Any]])?.first?["command"] != nil)
        #expect(anti["other"] != nil)
        #expect(installer.uninstalled(from: anti, agent: .antigravity)["brbuddy"] == nil)
    }

    @Test func codexHooksFeatureIsTurnedOnOnce() {
        #expect(AgentHookInstaller.enableCodexHooks(in: "") == "\n[features]\nhooks = true\n")
        #expect(AgentHookInstaller.enableCodexHooks(in: "model = \"o5\"\n[features]\nfoo = 1") ==
                "model = \"o5\"\n[features]\nhooks = true\nfoo = 1")
        #expect(AgentHookInstaller.enableCodexHooks(in: "[features]\nhooks = false") == "[features]\nhooks = true")
        #expect(AgentHookInstaller.enableCodexHooks(in: "[features]\nhooks = true") == nil)
        // A `hooks` key in another table is never touched.
        #expect(AgentHookInstaller.enableCodexHooks(in: "[mcp_servers.x]\nhooks = false\n[features]\nfoo = 1") ==
                "[mcp_servers.x]\nhooks = false\n[features]\nhooks = true\nfoo = 1")
        #expect(AgentHookInstaller.enableCodexHooks(in: "[profiles.a]\nhooks = true") ==
                "[profiles.a]\nhooks = true\n\n[features]\nhooks = true\n")
        #expect(AgentHookInstaller.enableCodexHooks(in: "[features] # flags\nhooks = false") ==
                "[features] # flags\nhooks = true")
    }

    @Test func writesThroughSymlinksAndKeepsPermissions() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appending(path: "brb-link-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let dotfiles = home.appending(path: "dotfiles/claude-settings.json")
        try fm.createDirectory(at: dotfiles.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"env":{"KEY":"x"}}"#.utf8).write(to: dotfiles)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dotfiles.path)
        let settings = home.appending(path: ".claude/settings.json")
        try fm.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: settings, withDestinationURL: dotfiles)

        let disk = AgentHookInstaller(home: home, helperPath: "/x/brbuddy-hook")
        try disk.install(.claude)
        #expect(try fm.destinationOfSymbolicLink(atPath: settings.path) == dotfiles.path)  // still a link
        #expect(disk.isInstalled(.claude))
        let mode = try fm.attributesOfItem(atPath: dotfiles.path)[.posixPermissions] as? NSNumber
        #expect(mode?.intValue == 0o600)
        #expect(fm.fileExists(atPath: dotfiles.path + ".brbuddy-backup"))

        // A brand-new config is private to the user.
        try disk.install(.grok)
        let fresh = try fm.attributesOfItem(atPath: disk.configURL(for: .grok).path)[.posixPermissions] as? NSNumber
        #expect(fresh?.intValue == 0o600)
    }

    @Test func installsOnDiskWithBackupAndRefusesBrokenFiles() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "brb-home-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let disk = AgentHookInstaller(home: home, helperPath: "/x/brbuddy-hook")
        let settings = home.appending(path: ".claude/settings.json")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"theme":"dark"}"#.utf8).write(to: settings)

        try disk.install(.claude)
        #expect(disk.isInstalled(.claude))
        #expect(FileManager.default.fileExists(atPath: settings.path + ".brbuddy-backup"))
        try disk.uninstall(.claude)
        #expect(!disk.isInstalled(.claude))
        let after = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any]
        #expect(after?["theme"] as? String == "dark" && after?["hooks"] == nil)

        try disk.install(.codex)
        let toml = try String(contentsOf: home.appending(path: ".codex/config.toml"), encoding: .utf8)
        #expect(toml.contains("hooks = true"))

        try disk.install(.grok)
        try disk.uninstall(.grok)
        #expect(!FileManager.default.fileExists(atPath: disk.configURL(for: .grok).path))

        let gemini = home.appending(path: ".gemini/settings.json")
        try FileManager.default.createDirectory(at: gemini.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: gemini)
        #expect(throws: AgentHookInstaller.InstallError.self) { try disk.install(.gemini) }
        #expect(try String(contentsOf: gemini, encoding: .utf8) == "{ not json")
    }
}

struct AgentSocketTests {
    @Test func listenerReceivesSentEvents() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "brb-\(UUID().uuidString.prefix(8)).sock").path
        let listener = AgentEventListener()
        let received = AsyncStream<AgentEvent>.makeStream()
        try listener.start(path: path) { received.continuation.yield($0) }
        defer { listener.stop() }

        let sent = AgentEvent(agent: .claude, event: "Stop", session: "s", cwd: nil, time: Date(timeIntervalSince1970: 1))
        #expect(AgentSocket.send(sent, path: path))
        var iterator = received.stream.makeAsyncIterator()
        let got = await iterator.next()
        // Same event, but stamped with when it arrived, not the time the sender claimed.
        #expect(got?.session == sent.session && got?.event == sent.event && got?.agent == sent.agent)
        #expect(abs((got?.time ?? .distantPast).timeIntervalSinceNow) < 5)
    }

    @Test func receivedEventsAreCappedAndRestamped() {
        let long = String(repeating: "x", count: 5000)
        let place = TerminalLocation(appPaths: Array(repeating: "/A.app", count: 20), tty: long)
        let sent = AgentEvent(agent: .claude, event: long, session: long, cwd: long,
                              time: Date(timeIntervalSince1970: 4_000_000_000), detail: long + "\n" + long, terminal: place)
        let now = Date(timeIntervalSince1970: 1_000)
        let got = sent.received(at: now)
        #expect(got.time == now)
        #expect(got.event.count == 64 && got.session.count == 128 && got.cwd?.count == 1024)
        #expect(got.detail?.count == AgentEvent.maxDetailLength && got.detail?.contains("\n") == false)
        #expect(got.terminal?.appPaths.count == 8 && got.terminal?.tty?.count == 64)
    }

    @Test func sendingWithNoAppRunningFailsQuietly() {
        let event = AgentEvent(agent: .claude, event: "Stop", session: "s", cwd: nil, time: Date())
        #expect(!AgentSocket.send(event, path: "/tmp/brb-nobody-\(UUID().uuidString.prefix(6)).sock"))
    }

    /// Runs the real helper binary the way an agent would, if it's been built.
    @Test func helperForwardsHookPayloadAndPrintsNothing() async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let helper = repo.appending(path: ".build/debug/brbuddy-hook")
        try #require(FileManager.default.isExecutableFile(atPath: helper.path), "run `swift build` first")

        let path = FileManager.default.temporaryDirectory.appending(path: "brb-\(UUID().uuidString.prefix(8)).sock").path
        let listener = AgentEventListener()
        let received = AsyncStream<AgentEvent>.makeStream()
        try listener.start(path: path) { received.continuation.yield($0) }
        defer { listener.stop() }

        let process = Process()
        process.executableURL = helper
        process.arguments = ["--agent", "claude", "--event", "Notification"]
        process.environment = ["BRBUDDY_SOCKET": path]
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        try process.run()
        stdin.fileHandleForWriting.write(Data(#"{"session_id":"abc","cwd":"/work/brbuddy","hook_event_name":"Notification"}"#.utf8))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        #expect(stdout.fileHandleForReading.readDataToEndOfFile().isEmpty)
        var iterator = received.stream.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event?.session == "abc" && event?.cwd == "/work/brbuddy" && event?.activity == .waiting)
    }
}

struct TerminalLocationTests {
    @Test func findsTheAppBundleOfAnExecutable() {
        #expect(TerminalLocation.appBundle(ofExecutable: "/Applications/iTerm.app/Contents/MacOS/iTermServer-3.5")
            == "/Applications/iTerm.app")
        #expect(TerminalLocation.appBundle(
            ofExecutable: "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin)")
            == "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Plugin).app")
        #expect(TerminalLocation.appBundle(ofExecutable: "/bin/zsh") == nil)
        #expect(TerminalLocation.appBundle(ofExecutable: "/Applications/Xcode.app/Contents/Developer/usr/bin/git") == nil)
    }

    @Test func eventsCarryTheLocationAndOldEventsStillDecode() throws {
        var event = AgentEvent(agent: .claude, event: "Notification", session: "s", cwd: "/p", time: Date(timeIntervalSince1970: 5))
        event.terminal = TerminalLocation(appPaths: ["/System/Applications/Utilities/Terminal.app"], tty: "/dev/ttys004")
        #expect(AgentEvent.decode(line: try event.encodedLine().dropLast()) == event)

        let old = Data(#"{"agent":"claude","event":"Stop","session":"s","time":5}"#.utf8)
        #expect(AgentEvent.decode(line: old)?.terminal == nil)
    }

    @Test func trackerKeepsTheLocationWhenLaterEventsLackIt() {
        var tracker = AgentTracker()
        let place = TerminalLocation(appPaths: ["/Applications/Ghostty.app"], tty: "/dev/ttys009")
        tracker.apply(AgentEvent(agent: .codex, event: "UserPromptSubmit", session: "a", cwd: "/p", time: Date(), terminal: place))
        tracker.apply(AgentEvent(agent: .codex, event: "Stop", session: "a", cwd: "/p", time: Date()))
        #expect(tracker.orderedSessions.first?.terminal == place)
    }

    @Test func readsThisProcesssParentWithoutCrashing() {
        // Whatever ran the tests (a terminal, an editor, CI) is fine; it only has to come back without trouble.
        let location = TerminalLocation.current()
        #expect(location?.tty?.hasPrefix("/dev/") ?? true)
        #expect(location?.appPaths.allSatisfy { $0.hasSuffix(".app") } ?? true)
    }
}
