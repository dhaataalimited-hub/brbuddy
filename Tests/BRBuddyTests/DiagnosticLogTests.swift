import BRBuddyCore
import Foundation
import Testing

struct DiagnosticLogTests {
    private func makeLog(maxBytes: Int = 10_000, keepFiles: Int = 3) -> DiagnosticLog {
        let folder = FileManager.default.temporaryDirectory.appending(path: "brbuddy-log-tests-\(UUID().uuidString)")
        return DiagnosticLog(folder: folder, maxBytes: maxBytes, keepFiles: keepFiles,
                             redaction: LogRedaction(home: "/Users/sam"))
    }

    @Test func writesOneLineEachWithCategoryAndTime() {
        let log = makeLog()
        defer { log.clear() }
        let date = Date(timeIntervalSince1970: 0)
        log.write(.tour, "Companion hung under the paw", at: date)
        log.write(.away, "BRB started (menu)", at: date)
        let lines = log.contents().split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasSuffix("[tour] Companion hung under the paw"))
        #expect(lines[1].hasSuffix("[away] BRB started (menu)"))
        #expect(lines[0].count == DiagnosticLog.line(.tour, "Companion hung under the paw", at: date).count - 1)
    }

    @Test func rollsOverAndKeepsOnlyTheNewestFiles() {
        let log = makeLog(maxBytes: 200, keepFiles: 3)
        defer { log.clear() }
        for index in 0..<40 { log.write(.app, "event number \(index)") }
        let text = log.contents()
        // Old lines are gone, new ones are there, oldest first.
        #expect(!text.contains("event number 0\n"))
        #expect(text.contains("event number 39\n"))
        let numbers = text.split(separator: "\n").compactMap { Int($0.split(separator: " ").last ?? "") }
        #expect(numbers == numbers.sorted())
        #expect(text.utf8.count <= 3 * 200)
        #expect(!FileManager.default.fileExists(atPath: log.folder.appending(path: "brbuddy.3.log").path))
    }

    @Test func clearRemovesEverything() {
        let log = makeLog()
        log.write(.app, "hello")
        log.clear()
        #expect(log.contents().isEmpty)
    }

    @Test func takesPersonalDetailsOut() {
        let redaction = LogRedaction(home: "/Users/sam")
        #expect(redaction.redact("Saved to /Users/sam/Library/x.json") == "Saved to ~/Library/x.json")
        #expect(redaction.redact("Read /Users/alex/Desktop/a") == "Read /Users/…/Desktop/a")
        #expect(redaction.redact("Mail sam.smith+test@example.co.uk now") == "Mail <email> now")
        #expect(redaction.redact("Nothing personal") == "Nothing personal")
    }

    @Test func logLinesAreRedactedOnTheWayIn() {
        let log = makeLog()
        defer { log.clear() }
        log.write(.agents, "Hooks written to /Users/sam/.claude/settings.json")
        #expect(log.contents().contains("~/.claude/settings.json"))
        #expect(!log.contents().contains("/Users/sam"))
    }

    @Test func reportHasAHeaderThenTheLog() {
        let report = DiagnosticReport.make(header: [("BRBuddy", "0.1.7 (70)"), ("Folder", "/Users/sam/x")],
                                           log: "line one\n", now: Date(timeIntervalSince1970: 0),
                                           timeZone: TimeZone(identifier: "Australia/Sydney")!,
                                           redaction: LogRedaction(home: "/Users/sam"))
        #expect(report.hasPrefix("BRBuddy diagnostic report\nCreated: 1970-01-01T10:00:00+10:00\nBRBuddy: 0.1.7 (70)\n"))
        #expect(report.contains("Folder: ~/x"))
        #expect(report.hasSuffix("---- Log (oldest first) ----\nline one\n"))
        #expect(DiagnosticReport.make(header: [], log: "").contains("(The log is empty.)"))
    }
}
