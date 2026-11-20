import AppKit
import BRBuddyCore
import Observation

/// The user's companion choice plus every community pack in the companions folder, with their frames loaded on
/// demand off the main thread. Owned by `AppState`.
@MainActor
@Observable
final class CompanionLibrary {
    var choice: CompanionCatalog.Choice {
        didSet { choice.save() }
    }

    private(set) var packs: [CompanionPack] = []
    private(set) var problems: [(folder: String, reason: String)] = []
    private(set) var importError: String?
    private var frames: [String: [CompanionMood: [CGImage]]] = [:]
    private var loading: Set<String> = []

    init() {
        choice = CompanionCatalog.Choice.load()
        reload()
    }

    func reload() {
        let scan = CompanionPackLibrary.scan()
        packs = scan.packs
        problems = scan.problems
        frames = frames.filter { id, _ in packs.contains { $0.id == id } }
    }

    func resolved(for agent: AgentKind?) -> CompanionCatalog.Resolved {
        CompanionCatalog.resolve(choice, agent: agent,
                                 availablePacks: Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0.agents) }))
    }

    func pack(id: String) -> CompanionPack? { packs.first { $0.id == id } }

    /// A pack's frames for a mood, falling back to its idle row. Empty until loaded; loading starts on first ask.
    func frames(pack id: String, mood: CompanionMood) -> [CGImage] {
        guard let all = frames[id] else {
            load(id)
            return []
        }
        if let moodFrames = all[mood], !moodFrames.isEmpty { return moodFrames }
        return all[.resting] ?? []
    }

    private func load(_ id: String) {
        guard !loading.contains(id), let pack = pack(id: id) else { return }
        loading.insert(id)
        Task.detached(priority: .userInitiated) {
            let cut = pack.frames()
            await MainActor.run { [weak self] in
                self?.frames[id] = cut
                self?.loading.remove(id)
            }
        }
    }

    /// Lets the user pick a pack folder, checks it, and copies it into the companions folder.
    func chooseAndImport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Choose a companion folder (it needs pet.json and a spritesheet)"
        panel.prompt = "Add Companion"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let pack = try CompanionPackLibrary.importPack(from: url)
            importError = nil
            reload()
            choice = .pack(pack.id)
        } catch {
            importError = "\(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func revealFolder() {
        let folder = CompanionPackLibrary.folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
