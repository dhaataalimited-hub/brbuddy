import Foundation

/// What the companion does when someone clicks it on the away screen: five reactions every companion shares, each
/// with its own face, motion, speech bubble and sound, plus a signature one whose sound and bubble are the
/// companion's own (`BoopSignature`).
public enum Boop: String, CaseIterable, Sendable {
    /// Squashes flat and springs back, eyes squeezed shut.
    case squish
    /// Wiggles and giggles.
    case giggle
    /// Spins round and gets dizzy.
    case spin
    /// Heart eyes, hearts floating up.
    case love
    /// Booped too much: puffs up and shakes.
    case grumpy
    /// The companion's own reaction: star eyes, a jump and a burst, with its signature sound and bubble.
    case signature

    /// How long the reaction plays.
    public var duration: TimeInterval {
        switch self {
        case .spin: 1.4
        case .grumpy: 1.3
        case .signature: 1.6
        default: 1.1
        }
    }

    public var bubble: String {
        switch self {
        case .squish: "boop!"
        case .giggle: "hehe"
        case .spin: "wheee"
        case .love: "♥"
        case .grumpy: "hey!"
        case .signature: "✨"
        }
    }

    /// The mood a community pack plays during the reaction (packs can't change their drawn face).
    public var packMood: CompanionMood {
        switch self {
        case .squish, .spin, .signature: .finished
        case .giggle, .love: .greeting
        case .grumpy: .oops
        }
    }
}

/// One boop: which reaction, and when it started.
public struct BoopEvent: Equatable, Sendable {
    public var boop: Boop
    public var at: Date

    public init(_ boop: Boop, at: Date) {
        self.boop = boop
        self.at = at
    }

    /// 0 at the click to 1 when the reaction ends; `nil` once it's over.
    public func progress(at now: Date) -> Double? {
        let p = now.timeIntervalSince(at) / boop.duration
        return (0...1).contains(p) ? p : nil
    }
}

/// Picks the next reaction: the five friendly ones (signature included) in a shuffled order, each once before any repeats (and never the
/// same twice in a row); five or more boops within three seconds makes the companion grumpy.
public struct BoopPicker: Sendable {
    public static let friendly: [Boop] = [.squish, .giggle, .spin, .love, .signature]
    public static let grumpyAfter = 5
    public static let grumpyWindow: TimeInterval = 3

    private var bag: [Boop] = []
    private var last: Boop?
    private var recent: [Date] = []

    public init() {}

    public mutating func next(now: Date = Date()) -> Boop {
        var generator = SystemRandomNumberGenerator()
        return next(now: now, using: &generator)
    }

    public mutating func next<G: RandomNumberGenerator>(now: Date, using generator: inout G) -> Boop {
        recent = recent.filter { now.timeIntervalSince($0) < Self.grumpyWindow } + [now]
        if recent.count >= Self.grumpyAfter {
            last = .grumpy
            return .grumpy
        }
        if bag.isEmpty {
            bag = Self.friendly.shuffled(using: &generator)
            if bag.first == last, bag.count > 1 { bag.swapAt(0, bag.count - 1) }
        }
        let boop = bag.removeFirst()
        last = boop
        return boop
    }
}

/// A companion's signature sound, synthesised like the rest. Built-ins have one each; a pack names one in
/// `pet.json` (`boopSignature`), else it gets `sparkle`.
public enum BoopSignature: String, CaseIterable, Sendable {
    case sparkle, fwoosh, plink, shimmer, zoom, breeze, cackle
    case chord, clickWheel, glassTap, bleeps, marimba, whirr, clack, fanfare, blueBox

    /// Each built-in companion's signature and what it says.
    public static func builtIn(_ id: String) -> (signature: BoopSignature, bubble: String) {
        switch id {
        case "ember": (.fwoosh, "fwoosh!")
        case "pebble": (.plink, "plink")
        case "prism": (.shimmer, "✦✦✦")
        case "comet": (.zoom, "zoom!")
        case "drift": (.breeze, "whooo")
        case "gremlin": (.cackle, "nyehehe")
        default: (.sparkle, Boop.signature.bubble)
        }
    }
}

/// Each reaction's sound, synthesised in code (no sound files): short squeaks, blips and chimes as 16-bit mono WAV.
public enum BoopSound {
    static let sampleRate = 44_100.0

    /// A WAV file of the reaction's sound, ready for `AVAudioPlayer(data:)`.
    /// `signature` is the companion's own sound, used for `Boop.signature`.
    public static func wav(for boop: Boop, signature: BoopSignature = .sparkle) -> Data {
        wavData(samples(tones(for: boop, signature: signature)))
    }

    /// One tone: frequency sweeps from `from` to `to` (Hz) over `length` seconds, with a soft attack and decay.
    struct Tone {
        var from: Double
        var to: Double
        var length: Double
        var start = 0.0
        var volume = 0.3
        /// Vibrato depth as a fraction of the frequency.
        var wobble = 0.0
        /// Adds the octave above for a brighter, bell-like sound.
        var bright = false
        /// Square-ish (buzzy) instead of a pure sine.
        var buzzy = false
        /// Filtered noise instead of a tone; `from`/`to` sweep the filter instead of the pitch.
        var noise = false
    }

    static func tones(for boop: Boop, signature: BoopSignature) -> [Tone] {
        switch boop {
        case .signature: tones(for: signature)
        case .squish:
            [Tone(from: 720, to: 260, length: 0.16)]
        case .giggle:
            (0..<4).map { i in Tone(from: 900 + Double(i) * 140, to: 1000 + Double(i) * 140, length: 0.07,
                                    start: Double(i) * 0.1, volume: 0.22) }
        case .spin:
            [Tone(from: 320, to: 1500, length: 0.55, volume: 0.22, wobble: 0.05)]
        case .love:
            [Tone(from: 1047, to: 1047, length: 0.35, volume: 0.2, bright: true),
             Tone(from: 1568, to: 1568, length: 0.5, start: 0.14, volume: 0.2, bright: true)]
        case .grumpy:
            [Tone(from: 190, to: 140, length: 0.32, volume: 0.16, wobble: 0.08, buzzy: true)]
        }
    }

    // Notes, in Hz.
    static let c5 = 523.25, e5 = 659.25, g5 = 783.99, c6 = 1046.5, e6 = 1318.5, g6 = 1568.0

    static func tones(for signature: BoopSignature) -> [Tone] {
        switch signature {
        case .sparkle:
            [c6, e6, g6, 2093].enumerated().map { Tone(from: $1, to: $1, length: 0.25, start: Double($0) * 0.07, volume: 0.15, bright: true) }
        case .fwoosh:
            [Tone(from: 300, to: 5000, length: 0.45, volume: 0.35, noise: true),
             Tone(from: 110, to: 260, length: 0.4, volume: 0.2)]
        case .plink:
            [Tone(from: 1900, to: 1800, length: 0.18, volume: 0.25, bright: true),
             Tone(from: 2500, to: 2450, length: 0.25, start: 0.12, volume: 0.18, bright: true)]
        case .shimmer:
            [e6, g6, 1976, 2637, 1976, 2637].enumerated().map { Tone(from: $1, to: $1, length: 0.3, start: Double($0) * 0.055, volume: 0.12, bright: true) }
        case .zoom:
            [Tone(from: 1700, to: 260, length: 0.55, volume: 0.25, wobble: 0.03)]
        case .breeze:
            [Tone(from: 400, to: 1400, length: 0.7, volume: 0.3, wobble: 0.3, noise: true)]
        case .cackle:
            (0..<6).map { i in Tone(from: i % 2 == 0 ? 330 : 280, to: i % 2 == 0 ? 300 : 250, length: 0.07,
                                    start: Double(i) * 0.085, volume: 0.15, buzzy: true) }
        case .chord:
            [261.63, 329.63, 392.0, c5, 1046.5].map { Tone(from: $0, to: $0, length: 1.0, volume: 0.12, bright: true) }
        case .clickWheel:
            (0..<7).map { i in Tone(from: 3200, to: 3000, length: 0.012, start: Double(i) * 0.055, volume: 0.35) }
        case .glassTap:
            [Tone(from: 2093, to: 2093, length: 0.2, volume: 0.18, bright: true),
             Tone(from: 2637, to: 2637, length: 0.3, start: 0.1, volume: 0.16, bright: true)]
        case .bleeps:
            [600.0, 900, 750, 1200, 500, 1000].enumerated().map { Tone(from: $1, to: $1, length: 0.05, start: Double($0) * 0.065, volume: 0.12, buzzy: true) }
        case .marimba:
            [g5, c6, e6, c6, g6].enumerated().map { Tone(from: $1, to: $1, length: 0.18, start: Double($0) * 0.11, volume: 0.2, bright: true) }
        case .whirr:
            [Tone(from: 180, to: 320, length: 0.3, volume: 0.12, wobble: 0.04, buzzy: true),
             Tone(from: 320, to: 200, length: 0.3, start: 0.3, volume: 0.12, wobble: 0.04, buzzy: true)]
        case .clack:
            [Tone(from: 1500, to: 1500, length: 0.04, volume: 0.5, noise: true),
             Tone(from: 380, to: 620, length: 0.2, start: 0.08, volume: 0.22)]
        case .fanfare:
            [Tone(from: c5, to: c5, length: 0.12, volume: 0.15, bright: true),
             Tone(from: e5, to: e5, length: 0.12, start: 0.13, volume: 0.15, bright: true),
             Tone(from: g5, to: g5, length: 0.12, start: 0.26, volume: 0.15, bright: true)]
                + [c5, e5, g5, c6].map { Tone(from: $0, to: $0, length: 0.7, start: 0.4, volume: 0.1, bright: true) }
        case .blueBox:
            [Tone(from: 2600, to: 2600, length: 0.22, volume: 0.15),
             Tone(from: 1300, to: 1300, length: 0.08, start: 0.3, volume: 0.15),
             Tone(from: 1700, to: 1700, length: 0.08, start: 0.42, volume: 0.15)]
        }
    }

    static func samples(_ tones: [Tone]) -> [Int16] {
        let total = tones.map { $0.start + $0.length }.max() ?? 0
        var mix = [Double](repeating: 0, count: Int(total * sampleRate) + 1)
        for tone in tones {
            var phase = 0.0
            var filtered = 0.0
            var seed: UInt64 = 0x9E3779B97F4A7C15
            let count = Int(tone.length * sampleRate)
            let offset = Int(tone.start * sampleRate)
            for i in 0..<count {
                let x = Double(i) / Double(count)
                let frequency = (tone.from + (tone.to - tone.from) * x) * (1 + tone.wobble * sin(2 * .pi * 18 * Double(i) / sampleRate))
                phase += 2 * .pi * frequency / sampleRate
                var wave = sin(phase)
                if tone.noise {
                    // White noise through a one-pole low-pass whose cutoff follows the sweep.
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let white = Double(Int64(bitPattern: seed) >> 11) / Double(1 << 52)
                    let alpha = min(1, 2 * .pi * frequency / sampleRate)
                    filtered += alpha * (white - filtered)
                    wave = filtered * 2.5
                }
                if tone.buzzy { wave = max(-0.6, min(0.6, wave * 2)) }
                if tone.bright { wave = 0.75 * wave + 0.25 * sin(2 * phase) }
                // 8 ms attack, then a curved decay to silence.
                let attack = min(1, Double(i) / (0.008 * sampleRate))
                let envelope = attack * pow(1 - x, tone.bright ? 2 : 1.2)
                mix[offset + i] += wave * envelope * tone.volume
            }
        }
        return mix.map { Int16(max(-1, min(1, $0)) * Double(Int16.max)) }
    }

    static func wavData(_ samples: [Int16]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(bytes)
        for sample in samples { append(sample) }
        return data
    }
}
