import Foundation

/// A colour stored as `#RRGGBB` in a design file.
public struct StudioColor: Codable, Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// From hue, saturation and brightness, each 0–1.
    public init(hue: Double, saturation: Double, brightness: Double) {
        let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        let m = brightness - c
        self.init(red: r + m, green: g + m, blue: b + m)
    }

    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    public var hex: String {
        func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let color = StudioColor(hex: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a #RRGGBB colour"))
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

extension BoopSignature: Codable {}

/// A companion made in Companion Studio from the same parts the built-in critters use. Saved as `design.json` in its
/// pack folder, so BRBuddy draws it live (with every reaction) and it can be opened and edited again; the folder's
/// spritesheets let other pet apps show it too.
public struct StudioDesign: Codable, Equatable, Sendable {
    public enum Body: String, Codable, CaseIterable, Sendable { case round, pebble, hex, cloud, spiky }
    public enum Ears: String, Codable, CaseIterable, Sendable { case none, round, pointy }
    public enum Accent: String, Codable, CaseIterable, Sendable { case none, sprout, starFreckles, wisps, snaggleTooth }

    public var name: String
    public var body: Body
    public var top: StudioColor
    public var bottom: StudioColor
    public var ears: Ears
    public var earColor: StudioColor
    public var accent: Accent
    public var accentColor: StudioColor
    /// White eyes and mouth instead of dark ones (for dark bodies).
    public var lightInk: Bool
    public var blush: Bool
    /// One eye bigger than the other.
    public var lopsided: Bool
    /// Hovers off the ground.
    public var floats: Bool
    public var signature: BoopSignature
    /// What it says on its signature boop.
    public var bubble: String

    /// What a new design starts as: a friendly peach blob.
    public static let starter = StudioDesign(
        name: "Buddy", body: .round, top: StudioColor(hex: "#FFB38A")!, bottom: StudioColor(hex: "#E07A5F")!,
        ears: .round, earColor: StudioColor(hex: "#E58A66")!, accent: .none, accentColor: StudioColor(hex: "#FFFFFF")!,
        lightInk: false, blush: true, lopsided: false, floats: false, signature: .sparkle, bubble: "ta-da!")

    public init(name: String, body: Body, top: StudioColor, bottom: StudioColor, ears: Ears, earColor: StudioColor,
                accent: Accent, accentColor: StudioColor, lightInk: Bool, blush: Bool, lopsided: Bool, floats: Bool,
                signature: BoopSignature, bubble: String) {
        self.name = name
        self.body = body
        self.top = top
        self.bottom = bottom
        self.ears = ears
        self.earColor = earColor
        self.accent = accent
        self.accentColor = accentColor
        self.lightInk = lightInk
        self.blush = blush
        self.lopsided = lopsided
        self.floats = floats
        self.signature = signature
        self.bubble = bubble
    }

    public static let maxNameLength = 30
    public static let maxBubbleLength = 24

    /// Names and bubbles trimmed to fit; an empty name becomes "Buddy".
    public var tidied: StudioDesign {
        var copy = self
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = name.isEmpty ? "Buddy" : String(name.prefix(Self.maxNameLength))
        copy.bubble = String(bubble.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxBubbleLength))
        return copy
    }

    /// A random design with colours that go together: one hue, a lighter top and a deeper bottom.
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> StudioDesign {
        let hue = Double.random(in: 0..<1, using: &generator)
        let dark = Double.random(in: 0..<1, using: &generator) < 0.2
        let top = StudioColor(hue: hue, saturation: dark ? 0.6 : 0.42, brightness: dark ? 0.7 : 0.98)
        let bottom = StudioColor(hue: hue + 0.04, saturation: dark ? 0.7 : 0.62, brightness: dark ? 0.42 : 0.84)
        let ear = StudioColor(hue: hue + 0.02, saturation: dark ? 0.65 : 0.55, brightness: dark ? 0.55 : 0.88)
        let accentColor = StudioColor(hue: hue + 0.5, saturation: 0.55, brightness: 0.95)
        let names = ["Biscuit", "Mochi", "Pip", "Nova", "Bean", "Ziggy", "Pudding", "Sprocket", "Moss", "Tofu", "Kiwi", "Blip"]
        let bubbles = ["ta-da!", "yay!", "boop back!", "hehe", "wow!", "yo!", "eep!"]
        return StudioDesign(
            name: names.randomElement(using: &generator)!, body: Body.allCases.randomElement(using: &generator)!,
            top: top, bottom: bottom, ears: Ears.allCases.randomElement(using: &generator)!, earColor: ear,
            accent: Accent.allCases.randomElement(using: &generator)!, accentColor: accentColor, lightInk: dark,
            blush: Bool.random(using: &generator), lopsided: Double.random(in: 0..<1, using: &generator) < 0.2,
            floats: Double.random(in: 0..<1, using: &generator) < 0.2,
            signature: BoopSignature.allCases.randomElement(using: &generator)!,
            bubble: bubbles.randomElement(using: &generator)!)
    }

    /// A folder name from the design's name: lowercase letters, digits and dashes, never empty.
    public var folderName: String {
        let slug = name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        let ascii = slug.unicodeScalars.filter { $0.isASCII }.map(String.init).joined()
        return ascii.isEmpty ? "studio-companion" : String(ascii.prefix(40))
    }
}

/// Writes a Studio design as a pack folder: `design.json`, `pet.json` and the two spritesheets.
public enum StudioPackWriter {
    public static let designFile = "design.json"

    /// A folder in `root` for this design: `preferred` when given (editing keeps its folder), else its name, with
    /// "-2", "-3"… added if that's taken.
    public static func folder(for design: StudioDesign, in root: URL, preferred: String? = nil) -> URL {
        if let preferred { return root.appending(path: preferred) }
        let base = design.folderName
        var candidate = base
        var n = 2
        while FileManager.default.fileExists(atPath: root.appending(path: candidate).path) {
            candidate = "\(base)-\(n)"
            n += 1
        }
        return root.appending(path: candidate)
    }

    /// The pack's `pet.json`: the Codex fields plus BRBuddy's (still sheet, signature, the design file).
    public static func manifest(for design: StudioDesign, id: String) throws -> Data {
        let manifest: [String: Any] = [
            "id": id, "displayName": design.name, "description": "Made in BRBuddy Companion Studio",
            "spriteVersionNumber": 1, "spritesheetPath": "spritesheet.png",
            "stillSpritesheetPath": "spritesheet-still.png", "boopSignature": design.signature.rawValue,
            "boopBubble": design.bubble, "studioDesign": designFile,
        ]
        return try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    }

    /// Writes everything into `folder`, replacing what's there. `sheet` and `stillSheet` are PNG data.
    public static func write(_ design: StudioDesign, sheet: Data, stillSheet: Data, to folder: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(design).write(to: folder.appending(path: designFile), options: .atomic)
        try sheet.write(to: folder.appending(path: "spritesheet.png"), options: .atomic)
        try stillSheet.write(to: folder.appending(path: "spritesheet-still.png"), options: .atomic)
        try manifest(for: design, id: folder.lastPathComponent).write(to: folder.appending(path: "pet.json"), options: .atomic)
    }
}
