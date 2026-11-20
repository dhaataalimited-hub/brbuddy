import CoreGraphics
import Foundation
import ImageIO

/// A community companion: a Codex pet folder (`pet.json` + spritesheet), optionally with BRBuddy's extra fields.
///
/// The Codex pet format (as documented by the awesome-codex-pet catalogue): an 8-column atlas of 192 × 208 cells,
/// v1 = 1536 × 1872 (9 rows), v2 = 1536 × 2288 (11 rows, `"spriteVersionNumber": 2`). Rows 0–8 are idle,
/// running-right, running-left, waving, jumping, failed, waiting, running, review. BRBuddy reads rows 0–8 and adds
/// optional `license`, `author` and `agents` (e.g. `["claude", "codex"]`) to `pet.json`; other apps ignore them.
public struct CompanionPack: Sendable, Identifiable {
    public enum LoadError: LocalizedError, Equatable {
        case missingManifest
        case unreadableManifest
        case missingSpritesheet(String)
        case unreadableImage
        case wrongSize(width: Int, height: Int)
        case tooLarge

        public var errorDescription: String? {
            switch self {
            case .missingManifest: "No pet.json in the folder."
            case .unreadableManifest: "pet.json isn't valid."
            case .missingSpritesheet(let name): "The spritesheet \(name) is missing."
            case .unreadableImage: "The spritesheet isn't an image macOS can read."
            case .wrongSize(let w, let h): "The spritesheet is \(w)×\(h); it must be 1536×1872 (v1) or 1536×2288 (v2)."
            case .tooLarge: "The spritesheet is over 20 MB."
            }
        }
    }

    public static let columns = 8
    public static let cellWidth = 192
    public static let cellHeight = 208
    static let maxBytes = 20 * 1024 * 1024

    /// The folder's name; stable across launches.
    public let id: String
    public let folder: URL
    public let displayName: String
    public let description: String?
    public let license: String?
    public let author: String?
    public let agents: [AgentKind]
    public let spriteVersion: Int
    public let spritesheetURL: URL

    struct Manifest: Decodable {
        var id: String?
        var displayName: String?
        var description: String?
        var spriteVersionNumber: Int?
        var spritesheetPath: String?
        var license: String?
        var author: String?
        var agents: [String]?
    }

    /// Reads and checks a pack folder without decoding the whole image.
    public static func load(from folder: URL) throws -> CompanionPack {
        let manifestURL = folder.appending(path: "pet.json")
        guard let data = try? Data(contentsOf: manifestURL) else { throw LoadError.missingManifest }
        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { throw LoadError.unreadableManifest }

        let sheetName = manifest.spritesheetPath ?? "spritesheet.webp"
        let sheetURL = folder.appending(path: sheetName).standardizedFileURL
        guard sheetURL.path.hasPrefix(folder.standardizedFileURL.path),  // no "../" escapes
              FileManager.default.fileExists(atPath: sheetURL.path) else { throw LoadError.missingSpritesheet(sheetName) }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: sheetURL.path)[.size] as? Int) ?? 0
        guard bytes <= maxBytes else { throw LoadError.tooLarge }

        guard let source = CGImageSourceCreateWithURL(sheetURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { throw LoadError.unreadableImage }
        let version: Int
        switch (width, height) {
        case (1536, 1872): version = 1
        case (1536, 2288): version = 2
        default: throw LoadError.wrongSize(width: width, height: height)
        }

        return CompanionPack(
            id: folder.lastPathComponent, folder: folder,
            displayName: manifest.displayName ?? manifest.id ?? folder.lastPathComponent,
            description: manifest.description, license: manifest.license, author: manifest.author,
            agents: (manifest.agents ?? []).compactMap(AgentKind.init(rawValue:)),
            spriteVersion: version, spritesheetURL: sheetURL)
    }

    /// Decodes the spritesheet and cuts each mood's row into frames, skipping blank cells. Do this once per pack,
    /// off the main thread.
    public func frames() -> [CompanionMood: [CGImage]] {
        guard let source = CGImageSourceCreateWithURL(spritesheetURL as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [:] }
        var result: [CompanionMood: [CGImage]] = [:]
        for mood in CompanionMood.allCases {
            let row = mood.codexRow
            result[mood] = (0..<Self.columns).compactMap { column in
                let rect = CGRect(x: column * Self.cellWidth, y: row * Self.cellHeight,
                                  width: Self.cellWidth, height: Self.cellHeight)
                guard let cell = sheet.cropping(to: rect), !Self.isBlank(cell) else { return nil }
                return cell
            }
        }
        return result
    }

    /// Whether a cell has no visible pixels (sampled on a small copy).
    static func isBlank(_ image: CGImage) -> Bool {
        let w = 24, h = 26
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return !stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 8 }
    }
}

/// Finds and loads every pack in BRBuddy's companions folder.
public enum CompanionPackLibrary {
    /// `~/Library/Application Support/BRBuddy/Companions`.
    public static var folder: URL { AgentSocket.supportFolder.appending(path: "Companions") }

    public struct Scan: Sendable {
        public var packs: [CompanionPack] = []
        /// Folders that aren't valid packs, with the reason.
        public var problems: [(folder: String, reason: String)] = []
    }

    public static func scan(_ root: URL = folder) -> Scan {
        var scan = Scan()
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        for folder in folders {
            do { scan.packs.append(try CompanionPack.load(from: folder)) }
            catch { scan.problems.append((folder.lastPathComponent, error.localizedDescription)) }
        }
        return scan
    }

    /// Checks a pack and copies it into the companions folder (replacing one with the same name).
    @discardableResult
    public static func importPack(from source: URL, into root: URL = folder) throws -> CompanionPack {
        _ = try CompanionPack.load(from: source)
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appending(path: source.lastPathComponent)
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.copyItem(at: source, to: target)
        return try CompanionPack.load(from: target)
    }
}
