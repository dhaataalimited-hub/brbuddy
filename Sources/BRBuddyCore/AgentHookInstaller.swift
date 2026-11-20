import Foundation

/// Adds and removes BRBuddy's hooks in each agent's own config file.
///
/// - Our entries are recognised by the helper's name in their command, so installing twice changes nothing and
///   other tools' hooks are never touched.
/// - The first time BRBuddy changes an existing file it saves a copy next to it (`<file>.brbuddy-backup`).
/// - A file that isn't valid JSON is never rewritten.
/// - Every hook command is the `brbuddy-hook` helper, which prints nothing and always exits 0, so it can't block
///   or change what an agent does.
///
/// Config shapes and locations follow AgentPet's installer (MIT); `enableCodexHooks` is adapted from AgentPet's
/// `CodexHookConfig`. See THIRD_PARTY_NOTICES.md.
public struct AgentHookInstaller: Sendable {
    public enum InstallError: LocalizedError, Equatable {
        case unreadableConfig(String)

        public var errorDescription: String? {
            switch self {
            case .unreadableConfig(let path): "\(path) isn't valid JSON, so BRBuddy left it alone. Fix it and try again."
            }
        }
    }

    enum Style { case nested, cursorFlat, antigravityGroup }

    public static let helperName = "brbuddy-hook"
    static let antigravityGroupKey = "brbuddy"
    static let antigravityMatcherEvents: Set<String> = ["PreToolUse", "PostToolUse"]

    public let home: URL
    public let helperPath: String

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, helperPath: String) {
        self.home = home
        self.helperPath = helperPath
    }

    // MARK: Where each agent keeps its hooks

    public func configURL(for agent: AgentKind) -> URL {
        switch agent {
        case .claude: home.appending(path: ".claude/settings.json")
        case .codex: home.appending(path: ".codex/hooks.json")
        case .gemini: home.appending(path: ".gemini/settings.json")
        case .cursor: home.appending(path: ".cursor/hooks.json")
        case .antigravity: home.appending(path: ".gemini/config/hooks.json")
        case .grok: home.appending(path: ".grok/hooks/brbuddy.json")
        }
    }

    /// The agent's own settings folder, which exists once the agent has been used on this Mac.
    public func agentFolderExists(_ agent: AgentKind) -> Bool {
        let folder: String = switch agent {
        case .claude: ".claude"
        case .codex: ".codex"
        case .gemini, .antigravity: ".gemini"
        case .cursor: ".cursor"
        case .grok: ".grok"
        }
        return FileManager.default.fileExists(atPath: home.appending(path: folder).path)
    }

    static func style(for agent: AgentKind) -> Style {
        switch agent {
        case .claude, .codex, .gemini, .grok: .nested
        case .cursor: .cursorFlat
        case .antigravity: .antigravityGroup
        }
    }

    func command(for agent: AgentKind, event: String) -> String {
        "\"\(helperPath)\" --agent \(agent.rawValue) --event \(event)"
    }

    static func isOurs(_ command: Any?) -> Bool {
        (command as? String)?.contains(helperName) ?? false
    }

    // MARK: Pure transforms (tested)

    func installed(into config: [String: Any], agent: AgentKind) -> [String: Any] {
        var config = uninstalled(from: config, agent: agent)
        switch Self.style(for: agent) {
        case .nested:
            var hooks = config["hooks"] as? [String: Any] ?? [:]
            for event in agent.hookEvents {
                var groups = hooks[event] as? [[String: Any]] ?? []
                groups.append(["hooks": [["type": "command", "command": command(for: agent, event: event)]]])
                hooks[event] = groups
            }
            config["hooks"] = hooks
        case .cursorFlat:
            config["version"] = config["version"] ?? 1
            var hooks = config["hooks"] as? [String: Any] ?? [:]
            for event in agent.hookEvents {
                var items = hooks[event] as? [[String: Any]] ?? []
                items.append(["type": "command", "command": command(for: agent, event: event)])
                hooks[event] = items
            }
            config["hooks"] = hooks
        case .antigravityGroup:
            var group = config[Self.antigravityGroupKey] as? [String: Any] ?? [:]
            for event in agent.hookEvents {
                var entries = group[event] as? [[String: Any]] ?? []
                let handler: [String: Any] = ["type": "command", "command": command(for: agent, event: event)]
                entries.append(Self.antigravityMatcherEvents.contains(event) ? ["matcher": "*", "hooks": [handler]] : handler)
                group[event] = entries
            }
            config[Self.antigravityGroupKey] = group
        }
        return config
    }

    func uninstalled(from config: [String: Any], agent: AgentKind) -> [String: Any] {
        var config = config
        let key = Self.style(for: agent) == .antigravityGroup ? Self.antigravityGroupKey : "hooks"
        guard var table = config[key] as? [String: Any] else { return config }
        for (event, value) in table {
            guard let entries = value as? [[String: Any]] else { continue }
            let kept = entries.filter { !Self.entryIsOurs($0) }
            if kept.isEmpty { table.removeValue(forKey: event) } else if kept.count != entries.count { table[event] = kept }
        }
        if table.isEmpty { config.removeValue(forKey: key) } else { config[key] = table }
        return config
    }

    func isInstalled(in config: [String: Any], agent: AgentKind) -> Bool {
        let key = Self.style(for: agent) == .antigravityGroup ? Self.antigravityGroupKey : "hooks"
        guard let table = config[key] as? [String: Any] else { return false }
        return table.values.contains { ($0 as? [[String: Any]])?.contains(where: Self.entryIsOurs) ?? false }
    }

    /// An entry is ours if it's a handler running our helper, or a group whose handlers include one.
    static func entryIsOurs(_ entry: [String: Any]) -> Bool {
        if isOurs(entry["command"]) { return true }
        return (entry["hooks"] as? [[String: Any]])?.contains { isOurs($0["command"]) } ?? false
    }

    /// Codex only reads hooks.json when hooks are on: makes sure `[features] hooks = true` is set, touching nothing
    /// else. Returns nil when it's already on.
    static func enableCodexHooks(in toml: String) -> String? {
        var lines = toml.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let compact = line.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
            if compact.hasPrefix("#") { continue }
            if compact.hasPrefix("hooks=true") { return nil }
            if compact.hasPrefix("hooks=") {
                lines[index] = "hooks = true"
                return lines.joined(separator: "\n")
            }
        }
        if let features = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "[features]" }) {
            lines.insert("hooks = true", at: features + 1)
            return lines.joined(separator: "\n")
        }
        var result = toml
        if !result.isEmpty, !result.hasSuffix("\n") { result += "\n" }
        return result + "\n[features]\nhooks = true\n"
    }

    // MARK: On disk

    public func isInstalled(_ agent: AgentKind) -> Bool {
        (try? readConfig(configURL(for: agent))).map { isInstalled(in: $0, agent: agent) } ?? false
    }

    public func install(_ agent: AgentKind) throws {
        let url = configURL(for: agent)
        try write(installed(into: try readConfig(url), agent: agent), to: url)
        if agent == .codex {
            let tomlURL = home.appending(path: ".codex/config.toml")
            let toml = (try? String(contentsOf: tomlURL, encoding: .utf8)) ?? ""
            if let updated = Self.enableCodexHooks(in: toml) {
                try backUpOnce(tomlURL)
                try Data(updated.utf8).write(to: tomlURL, options: .atomic)
            }
        }
    }

    public func uninstall(_ agent: AgentKind) throws {
        let url = configURL(for: agent)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let remaining = uninstalled(from: try readConfig(url), agent: agent)
        if agent == .grok, remaining.isEmpty {
            try FileManager.default.removeItem(at: url)  // Our own file.
        } else {
            try write(remaining, to: url)
        }
    }

    func readConfig(_ url: URL) throws -> [String: Any] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InstallError.unreadableConfig(url.path)
        }
        return object
    }

    private func write(_ config: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backUpOnce(url)
        let data = try JSONSerialization.data(withJSONObject: config,
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }

    private func backUpOnce(_ url: URL) throws {
        let backup = URL(fileURLWithPath: url.path + ".brbuddy-backup")
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path), !fm.fileExists(atPath: backup.path) else { return }
        try fm.copyItem(at: url, to: backup)
    }
}
