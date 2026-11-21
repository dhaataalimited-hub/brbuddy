import AppKit
import BRBuddyCore
import Observation

/// The user's companion choice plus every community pack in the companions folder, with their frames loaded on
/// demand off the main thread. Owned by `AppState`.
@MainActor
@Observable
final class CompanionLibrary {
    var choice: CompanionCatalog.Choice {
        didSet {
            choice.save()
            if choice == .shuffle, oldValue != .shuffle { shuffleNext() }
        }
    }
    /// Shuffle mode's running order; moves on each time BRB starts.
    private(set) var shuffle = CompanionShuffle.load()

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
        frames = frames.filter { key, _ in packs.contains { $0.id == key || $0.id + Self.stillSuffix == key } }
    }

    func resolved(for agent: AgentKind?) -> CompanionCatalog.Resolved {
        CompanionCatalog.resolve(choice, agent: agent,
                                 availablePacks: Dictionary(uniqueKeysWithValues: packs.map { ($0.id, $0.agents) }),
                                 shufflePick: shuffle.current)
    }

    /// In Shuffle mode, moves on to the next companion (called each time BRB starts, and by "Next" in Settings).
    func shuffleNext() {
        guard choice == .shuffle else { return }
        shuffle.advance(pool: CompanionShuffle.pool(packs: packs.map(\.id)))
        shuffle.save()
    }

    func pack(id: String) -> CompanionPack? { packs.first { $0.id == id } }

    /// A pack's frames for a mood, falling back to its idle row. Empty until loaded; loading starts on first ask.
    /// `still` asks for the pack's still sheet (body held, face moving), used on battery; packs without one give
    /// their normal frames.
    func frames(pack id: String, mood: CompanionMood, still: Bool = false) -> [CGImage] {
        let useStill = still && pack(id: id)?.stillSpritesheetURL != nil
        let key = useStill ? id + Self.stillSuffix : id
        guard let all = frames[key] else {
            load(id, still: useStill)
            return useStill ? frames(pack: id, mood: mood) : []
        }
        if let moodFrames = all[mood], !moodFrames.isEmpty { return moodFrames }
        return all[.resting] ?? []
    }

    private static let stillSuffix = "#still"

    private func load(_ id: String, still: Bool) {
        let key = still ? id + Self.stillSuffix : id
        guard !loading.contains(key), let pack = pack(id: id) else { return }
        loading.insert(key)
        Task.detached(priority: .userInitiated) {
            let cut = pack.frames(still: still)
            await MainActor.run { [weak self] in
                self?.frames[key] = cut
                self?.loading.remove(key)
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
