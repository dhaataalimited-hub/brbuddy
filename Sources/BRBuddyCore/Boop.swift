import Foundation

/// What the companion does when someone clicks it on the away screen: five reactions, each with its own face,
/// motion, speech bubble and sound.
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

    /// How long the reaction plays.
    public var duration: TimeInterval {
        switch self {
        case .spin: 1.4
        case .grumpy: 1.3
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
        }
    }

    /// The mood a community pack plays during the reaction (packs can't change their drawn face).
    public var packMood: CompanionMood {
        switch self {
        case .squish, .spin: .finished
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

/// Picks the next reaction: the four friendly ones in a shuffled order, each once before any repeats (and never the
/// same twice in a row); five or more boops within three seconds makes the companion grumpy.
public struct BoopPicker: Sendable {
    public static let friendly: [Boop] = [.squish, .giggle, .spin, .love]
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

/// Each reaction's sound, synthesised in code (no sound files): short squeaks, blips and chimes as 16-bit mono WAV.
public enum BoopSound {
    static let sampleRate = 44_100.0

    /// A WAV file of the reaction's sound, ready for `AVAudioPlayer(data:)`.
    public static func wav(for boop: Boop) -> Data {
        wavData(samples(for: boop))
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
    }

    static func tones(for boop: Boop) -> [Tone] {
        switch boop {
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

    static func samples(for boop: Boop) -> [Int16] {
        let tones = tones(for: boop)
        let total = tones.map { $0.start + $0.length }.max() ?? 0
        var mix = [Double](repeating: 0, count: Int(total * sampleRate) + 1)
        for tone in tones {
            var phase = 0.0
            let count = Int(tone.length * sampleRate)
            let offset = Int(tone.start * sampleRate)
            for i in 0..<count {
                let x = Double(i) / Double(count)
                let frequency = (tone.from + (tone.to - tone.from) * x) * (1 + tone.wobble * sin(2 * .pi * 18 * Double(i) / sampleRate))
                phase += 2 * .pi * frequency / sampleRate
                var wave = sin(phase)
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
