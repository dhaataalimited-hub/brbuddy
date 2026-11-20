import Darwin
import Foundation

/// The local Unix socket between `brbuddy-hook` (run by agents) and the app. Only this user can connect (0600).
public enum AgentSocket {
    /// `~/Library/Application Support/BRBuddy/agents.sock`, or `BRBUDDY_SOCKET` if set (tests).
    public static var defaultPath: String {
        if let override = ProcessInfo.processInfo.environment["BRBUDDY_SOCKET"], !override.isEmpty { return override }
        return supportFolder.appending(path: "agents.sock").path
    }

    public static var supportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "BRBuddy")
    }

    static func address(_ path: String) -> sockaddr_un? {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard bytes.count < capacity else { return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        return addr
    }

    static func setTimeout(_ fd: Int32, _ option: Int32, seconds: Int) {
        var tv = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, option, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    /// Sends one event. Returns false (quietly) if the app isn't running. Never waits more than a second.
    @discardableResult
    public static func send(_ event: AgentEvent, path: String = defaultPath) -> Bool {
        guard var addr = address(path), let line = try? event.encodedLine() else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        setTimeout(fd, SO_SNDTIMEO, seconds: 1)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return false }
        return line.withUnsafeBytes { write(fd, $0.baseAddress, line.count) } == line.count
    }
}

/// Listens on the agent socket and hands each event to a callback on its own queue.
public final class AgentEventListener: @unchecked Sendable {
    private let queue = DispatchQueue(label: "brbuddy.agent-events")
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?
    private var path = ""

    public init() {}

    deinit { stop() }

    public func start(path: String = AgentSocket.defaultPath, onEvent: @escaping @Sendable (AgentEvent) -> Void) throws {
        stop()
        self.path = path
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        unlink(path)  // A socket left behind by a crash.
        guard var addr = AgentSocket.address(path) else { throw POSIXError(.ENAMETOOLONG) }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EIO) }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(fd, 32) == 0 else {
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        self.fd = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [fd] in
            while true {
                let client = accept(fd, nil, nil)
                guard client >= 0 else { break }
                Self.readEvents(from: client).forEach(onEvent)
                close(client)
            }
        }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
        if fd >= 0 {
            close(fd)
            fd = -1
            unlink(path)
        }
    }

    private static func readEvents(from client: Int32) -> [AgentEvent] {
        _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
        AgentSocket.setTimeout(client, SO_RCVTIMEO, seconds: 1)
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < 64 * 1024 {
            let count = read(client, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data.split(separator: 0x0A).compactMap { AgentEvent.decode(line: Data($0)) }
    }
}
