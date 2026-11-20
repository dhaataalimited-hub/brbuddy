@testable import BRBuddyCore
import Foundation
import Testing

struct ANSIParserTests {
    @Test func parsesColoursAndResets() {
        let lines = ANSIParser.parse("\u{1B}[1;32mok\u{1B}[0m done\n\u{1B}[38;5;208mo\u{1B}[38;2;1;2;3mr\u{1B}[39mx")
        #expect(lines.count == 2)
        #expect(lines[0].map(\.text) == ["ok", " done"])
        #expect(lines[0][0].style.bold && lines[0][0].style.foreground == .indexed(2))
        #expect(lines[0][1].style == TerminalStyle())
        #expect(lines[1].map(\.style.foreground) == [.indexed(208), .rgb(1, 2, 3), .default])
    }

    @Test func dropsCursorMovesTitlesAndControlCharacters() {
        let lines = ANSIParser.parse("a\u{1B}[2Kb\u{1B}]0;title\u{07}c\r\u{01}d\te")
        #expect(lines.map { $0.map(\.text).joined() } == ["abcd    e"])
    }

    @Test func paletteCoversAllRanges() {
        #expect(TerminalColor.default.components == nil)
        #expect(TerminalColor.indexed(15).components?.red == 1)
        #expect(TerminalColor.indexed(16).components?.red == 0)
        #expect(TerminalColor.indexed(231).components?.blue == 1)
        let grey = TerminalColor.indexed(244).components
        #expect(grey?.red == grey?.green)
    }
}

struct TmuxReaderTests {
    let output = """
    %0\tzsh\t/Users/me\twork:0.0\t0
    %3\t2.1.328\t/Users/me/brbuddy\twork:1.0\t0
    %5\tvim\t/Users/me/brbuddy\twork:1.1\t1
    %7\tcodex\t/Users/me/other\tside:0.0\t0
    garbage line
    """

    @Test func parsesPanes() {
        let panes = TmuxReader.parsePanes(output)
        #expect(panes.map(\.id) == ["%0", "%3", "%5", "%7"])
        #expect(panes[2].isActive && panes[1].folderName == "brbuddy")
    }

    @Test func choosesTheAgentPaneInTheAgentsFolder() {
        let panes = TmuxReader.parsePanes(output)
        // Claude Code shows its version as the command; it's in the agent's folder.
        #expect(TmuxReader.choosePane(panes, agentFolder: "/Users/me/brbuddy")?.id == "%3")
        #expect(TmuxReader.choosePane(panes, agentFolder: "/Users/me/other")?.id == "%7")
        #expect(TmuxReader.choosePane(Array(panes.prefix(1)) + [panes[2]], agentFolder: nil)?.id == "%5")
        #expect(TmuxReader.choosePane([], agentFolder: nil) == nil)
    }
}

struct ActivityFeedTests {
    @Test func eventDetailsDescribeToolsNotPrompts() {
        let bash = AgentEvent.fromHook(agent: .claude, event: "PreToolUse",
                                       stdin: Data(#"{"session_id":"s","tool_name":"Bash","tool_input":{"command":"swift test\n--parallel"}}"#.utf8))
        #expect(bash.detail == "Bash: swift test --parallel")
        let prompt = AgentEvent.fromHook(agent: .claude, event: "UserPromptSubmit",
                                         stdin: Data(#"{"session_id":"s","prompt":"my secret plan"}"#.utf8))
        #expect(prompt.detail == nil)
        let note = AgentEvent.fromHook(agent: .claude, event: "Notification",
                                       stdin: Data(#"{"session_id":"s","message":"Claude needs your permission to use Bash"}"#.utf8))
        #expect(note.detail == "Claude needs your permission to use Bash")
        let long = AgentEvent.fromHook(agent: .grok, event: "PostToolUse",
                                       stdin: Data(#"{"sessionId":"s","toolName":"run","toolInput":{"command":"\#(String(repeating: "x", count: 300))"}}"#.utf8))
        #expect(long.detail?.count == AgentEvent.maxDetailLength)
    }

    @Test func feedRecordsAndCollapsesRepeats() {
        var log = AgentActivityLog()
        func event(_ name: String, _ detail: String?, _ t: TimeInterval) -> AgentEvent {
            AgentEvent(agent: .claude, event: name, session: "s", cwd: "/p/brbuddy", time: Date(timeIntervalSince1970: t), detail: detail)
        }
        log.record(event("UserPromptSubmit", nil, 0))
        log.record(event("PreToolUse", "Bash: ls", 1))
        log.record(event("PreToolUse", "Bash: ls", 2))
        log.record(event("Notification", "permission?", 3))
        log.record(event("Stop", nil, 4))
        log.record(event("Unknown", nil, 5))
        #expect(log.entries.map(\.text) == ["got a new prompt", "Bash: ls", "needs you: permission?", "finished"])
        #expect(log.entries[1].time == Date(timeIntervalSince1970: 2))
        let line = log.terminalLines(timeZone: TimeZone(identifier: "UTC")!)[1]
        #expect(line.map(\.text).joined() == "00:00:02  ⚙ Claude Code · brbuddy  Bash: ls")
    }

    @Test func feedKeepsOnlyTheLatestEntries() {
        var log = AgentActivityLog()
        for i in 0..<200 {
            log.record(AgentEvent(agent: .codex, event: "PreToolUse", session: "s", cwd: nil, time: Date(), detail: "step \(i)"))
        }
        #expect(log.entries.count == AgentActivityLog.capacity && log.entries.last?.text == "step 199")
    }
}

struct MirrorModeTests {
    @Test func defaultsToOffAndRoundTrips() throws {
        let store = try #require(UserDefaults(suiteName: "brbuddy.tests.\(UUID().uuidString)"))
        #expect(TerminalMirrorMode.load(from: store) == .off)
        TerminalMirrorMode.activityFeed.save(to: store)
        #expect(TerminalMirrorMode.load(from: store) == .activityFeed)
    }
}
