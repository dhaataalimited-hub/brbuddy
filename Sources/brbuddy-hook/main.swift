import BRBuddyCore
import Foundation

// brbuddy-hook --agent <claude|codex|gemini|cursor|antigravity|grok> --event <EventName>
//
// Run by an AI agent's hooks. Reads the agent's JSON from stdin, forwards one event to BRBuddy over the local
// socket, and exits. It must never get in the agent's way: it prints nothing (some agents add hook output to the
// conversation), always exits 0, and gives up after about two seconds.

var agent: AgentKind?
var event: String?
var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--agent": agent = arguments.next().flatMap(AgentKind.init(rawValue:))
    case "--event": event = arguments.next()
    default: break
    }
}
guard let agent, let event else { exit(0) }

/// Reads stdin on a background thread so an agent that never closes it can't hold us up.
func readStdin(timeout: TimeInterval) -> Data {
    guard isatty(STDIN_FILENO) == 0 else { return Data() }
    final class Box: @unchecked Sendable { var data = Data() }
    let box = Box()
    let done = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
        box.data = FileHandle.standardInput.readData(ofLength: 1 << 20)
        done.signal()
    }
    return done.wait(timeout: .now() + timeout) == .success ? box.data : Data()
}

let input = readStdin(timeout: 1)
var hookEvent = AgentEvent.fromHook(agent: agent, event: event, stdin: input)
hookEvent.terminal = TerminalLocation.current()
AgentSocket.send(hookEvent)
exit(0)
