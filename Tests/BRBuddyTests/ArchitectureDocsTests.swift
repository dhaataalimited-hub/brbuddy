import Foundation
import Testing

// Template from the architecture-map skill (first used in DuoPrompt, 2026-11-06).
// BRBuddy: SwiftPM layout, so the app sources are `Sources/` (both targets) and this file is in `Tests/BRBuddyTests/`.
// Swift 6 / Swift Testing. Reads the repo through #filePath; it skips itself
// where the repo isn't readable.

/// Keeps `docs/architecture` honest: every file it names exists, every type under a flow page's "Code to check" is
/// still declared, and every app source file is in the README's file index.
struct ArchitectureDocsTests {
    static let appFolder = "Sources"

    struct File { var name: String; var text: String }

    static let testsRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static let repo = testsRoot.deletingLastPathComponent().deletingLastPathComponent()  // Tests/BRBuddyTests → repo
    static let appRoot = repo.appending(path: appFolder, directoryHint: .isDirectory)
    static let docsRoot = repo.appending(path: "docs/architecture", directoryHint: .isDirectory)

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: appRoot.path)
            && FileManager.default.fileExists(atPath: docsRoot.appending(path: "README.md").path)
    }

    static func files(in root: URL, withExtension ext: String) throws -> [File] {
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return try enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == ext }.map { url in
            File(name: String(url.path.dropFirst(root.path.count + 1)),
                 text: try String(contentsOf: url, encoding: .utf8))
        }
    }

    static func appSources() throws -> [File] {
        let files = try files(in: appRoot, withExtension: "swift")
        try #require(!files.isEmpty, "No Swift files found in \(appRoot.path): check appFolder")
        return files
    }

    /// Text between backticks, on one line.
    static func codeSpans(in text: String) -> [String] {
        text.matches(of: #/`([^`\n]+)`/#).map { String($0.output.1) }
    }

    /// Lines under a "## Code to check" heading, up to the next heading.
    static func codeToCheck(in text: String) -> String {
        var inside = false
        var kept: [Substring] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") { inside = line.hasPrefix("## Code to check") }
            else if inside { kept.append(line) }
        }
        return kept.joined(separator: "\n")
    }

    /// Whether `name` (a path relative to the app folder, or a bare file name) is an app source file.
    static func exists(_ name: String, in files: [File]) -> Bool {
        name.contains("/") ? files.contains { $0.name == name }
                           : files.contains { ($0.name as NSString).lastPathComponent == name }
    }

    @Test(.enabled(if: isAvailable)) func everyNamedFileExists() throws {
        let sources = try Self.appSources()
        var missing: [String] = []
        for doc in try Self.files(in: Self.docsRoot, withExtension: "md") {
            for span in Self.codeSpans(in: doc.text) where span.hasSuffix(".swift") && !span.contains(" ") {
                if !Self.exists(span, in: sources) { missing.append("\(doc.name): \(span)") }
            }
        }
        for doc in try Self.files(in: Self.docsRoot, withExtension: "html") {
            for match in doc.text.matches(of: #/[A-Za-z0-9_+\/]+\.swift/#) {
                let name = String(match.output)
                if !Self.exists(name, in: sources) { missing.append("\(doc.name): \(name)") }
            }
        }
        #expect(missing.isEmpty, "Named in the architecture docs but not in \(Self.appFolder)/ (renamed or deleted? update the doc): \(missing)")
    }

    @Test(.enabled(if: isAvailable)) func everyTypeToCheckIsDeclared() throws {
        let sources = try Self.appSources().map(\.text) + Self.files(in: Self.testsRoot, withExtension: "swift").map(\.text)
        // One pass over every source, not a regex per name.
        let declared = Set(sources.flatMap { text in
            text.matches(of: #/\b(?:class|struct|enum|actor|protocol|typealias)\s+([A-Z][A-Za-z0-9]*)/#)
                .map { String($0.output.1) }
        })
        var missing: [String] = []
        for doc in try Self.files(in: Self.docsRoot, withExtension: "md") {
            for span in Self.codeSpans(in: Self.codeToCheck(in: doc.text))
            where span.wholeMatch(of: #/[A-Z][A-Za-z0-9]*/#) != nil && !declared.contains(span) {
                missing.append("\(doc.name): \(span)")
            }
        }
        #expect(missing.isEmpty, "Listed under \"Code to check\" but no longer declared (renamed? update the flow page): \(missing)")
    }

    @Test(.enabled(if: isAvailable)) func everySourceFileIsInTheIndex() throws {
        let readme = try String(contentsOf: Self.docsRoot.appending(path: "README.md"), encoding: .utf8)
        let indexed = Set(Self.codeSpans(in: readme))
        let unmapped = try Self.appSources().map(\.name).filter { !indexed.contains($0) }.sorted()
        #expect(unmapped.isEmpty, "Not in docs/architecture/README.md \"File index\" (add a line for each): \(unmapped)")
    }

    @Test func checksFindNamesAndSections() {
        let page = "Intro `NotChecked`\n## Code to check\n- `A.swift`, `Types`: `Alpha`, `Beta`\n## Next\n`Gamma`"
        #expect(Self.codeSpans(in: Self.codeToCheck(in: page)) == ["A.swift", "Types", "Alpha", "Beta"])
    }
}
