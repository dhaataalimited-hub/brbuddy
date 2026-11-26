import Foundation

/// BRBuddy's own log, kept on disk so a user can send it when something goes wrong on their Mac (**Send Logs…**).
///
/// One line per event, in a small set of rolling files in `~/Library/Application Support/BRBuddy/Logs`: when
/// `brbuddy.log` would pass `maxBytes` it becomes `brbuddy.1.log` (and so on, up to `keepFiles` files), so the log
/// never grows past a few MB. Every line goes through `LogRedaction` before it's written. Safe to call from any thread.
public final class DiagnosticLog: @unchecked Sendable {
    /// Which part of BRBuddy a line is about.
    public enum Category: String, CaseIterable, Sendable {
        case app, tour, menu, windows, away, agents, walkAway, updates, keepAwake
    }

    public let folder: URL
    public let maxBytes: Int
    public let keepFiles: Int
    private let redaction: LogRedaction
    private let lock = NSLock()

    public static let shared = DiagnosticLog(folder: defaultFolder)

    /// `~/Library/Application Support/BRBuddy/Logs`.
    public static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "BRBuddy/Logs", directoryHint: .isDirectory)
    }

    public init(folder: URL, maxBytes: Int = 512 * 1024, keepFiles: Int = 4, redaction: LogRedaction = LogRedaction()) {
        self.folder = folder
        self.maxBytes = maxBytes
        self.keepFiles = max(1, keepFiles)
        self.redaction = redaction
    }

    /// The file being written now; older ones are `brbuddy.1.log`, `brbuddy.2.log`...
    public var currentFile: URL { file(0) }

    func file(_ index: Int) -> URL {
        folder.appending(path: index == 0 ? "brbuddy.log" : "brbuddy.\(index).log")
    }

    /// "2026-11-27 00:12:39.123 [tour] Companion hung under the paw"
    public static func line(_ category: Category, _ message: String, at date: Date) -> String {
        "\(timestamp.string(from: date)) [\(category.rawValue)] \(message)\n"
    }

    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    public func write(_ category: Category, _ message: String, at date: Date = Date()) {
        let data = Data(Self.line(category, redaction.redact(message), at: date).utf8)
        lock.lock()
        defer { lock.unlock() }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let size = (try? fileManager.attributesOfItem(atPath: currentFile.path)[.size] as? Int) ?? 0
        if size > 0, size + data.count > maxBytes { rotate() }
        if let handle = try? FileHandle(forWritingTo: currentFile) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: currentFile)
        }
    }

    /// Everything still on disk, oldest first.
    public func contents() -> String {
        lock.lock()
        defer { lock.unlock() }
        return (0..<keepFiles).reversed()
            .compactMap { try? String(contentsOf: file($0), encoding: .utf8) }
            .joined()
    }

    /// Deletes every log file.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        for index in 0..<keepFiles { try? FileManager.default.removeItem(at: file(index)) }
    }

    /// Shifts each file one place older and drops the oldest. Called with the lock held.
    private func rotate() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: file(keepFiles - 1))
        for index in stride(from: keepFiles - 2, through: 0, by: -1) {
            try? fileManager.moveItem(at: file(index), to: file(index + 1))
        }
    }
}

/// Takes personal details out of a log line before it's written: the home folder (which carries the user's account
/// name), any other `/Users/<name>` path, and email addresses.
public struct LogRedaction: Sendable {
    public let home: String

    public init(home: String = NSHomeDirectory()) {
        self.home = home
    }

    public func redact(_ text: String) -> String {
        var text = text
        if home.count > 1 { text = text.replacingOccurrences(of: home, with: "~") }
        text = text.replacingOccurrences(of: #"/Users/[^/\s"']+"#, with: "/Users/…", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, with: "<email>",
                                         options: .regularExpression)
        return text
    }
}

/// The text a user sends with **Send Logs…**: a short header about the Mac and BRBuddy, then the log.
public enum DiagnosticReport {
    /// The log's lines are in local time, so "Created" is too, with its offset from UTC.
    public static func make(header: [(String, String)], log: String, now: Date = Date(),
                            timeZone: TimeZone = .current, redaction: LogRedaction = LogRedaction()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        let created = formatter.string(from: now)
        let rows = header.map { "\($0.0): \(redaction.redact($0.1))" }.joined(separator: "\n")
        let body = log.isEmpty ? "(The log is empty.)\n" : log
        return """
        BRBuddy diagnostic report
        Created: \(created)
        \(rows)

        ---- Log (oldest first) ----
        \(body)
        """
    }
}
