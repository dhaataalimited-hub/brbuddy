import AVFoundation
import BRBuddyCore
import SwiftUI

/// Plays the boop sounds, synthesised once per reaction by `BoopSound`.
@MainActor
enum BoopPlayer {
    private static var sounds: [String: Data] = [:]
    private static var playing: AVAudioPlayer?

    /// `signature` is the companion's own sound, played for `Boop.signature`.
    static func play(_ boop: Boop, signature: BoopSignature) {
        let key = boop == .signature ? "signature." + signature.rawValue : boop.rawValue
        let data = sounds[key] ?? BoopSound.wav(for: boop, signature: signature)
        sounds[key] = data
        playing?.stop()
        playing = try? AVAudioPlayer(data: data)
        playing?.play()
    }
}

extension View {
    /// How the whole companion moves during a boop: squash and spring back, wiggle, spin, swell, shake.
    func boopMotion(_ boop: Boop, progress p: Double) -> some View {
        let fade = 1 - p
        let squash = boop == .squish ? 0.24 * exp(-4 * p) * cos(p * 20) : 0
        let rotation: Double = switch boop {
        case .giggle: 9 * fade * sin(p * 42)
        case .spin: 360 * (p < 0.6 ? (1 - cos(p / 0.6 * .pi)) / 2 : 1)
        case .signature: 10 * fade * sin(p * 24)
        default: 0
        }
        let hop: Double = switch boop {
        case .spin: -34 * sin(min(p / 0.6, 1) * .pi)
        case .love: -10 * sin(p * .pi)
        case .signature: -40 * max(0, sin(p * 2 * .pi))
        default: 0
        }
        let swell: Double = switch boop {
        case .love: 1 + 0.08 * sin(p * .pi)
        case .grumpy: 1 + 0.07 * fade
        case .signature: 1 + 0.1 * sin(p * .pi)
        default: 1
        }
        let shake = boop == .grumpy ? 7 * fade * sin(p * 70) : 0
        return self
            .scaleEffect(x: (1 + squash) * swell, y: (1 - squash) * swell, anchor: .bottom)
            .rotationEffect(.degrees(rotation), anchor: boop == .spin ? .center : .bottom)
            .offset(x: shake, y: hop)
    }
}

/// The boop's speech bubble and effects over either kind of companion: impact sparkles, music notes, orbiting stars,
/// floating hearts, steam puffs, or the signature's rainbow burst. Laid out in the critter's 300 × 260 design space
/// and scaled to fit.
struct BoopFlair: View {
    let boop: Boop
    let progress: Double
    /// What the companion says on its signature boop.
    var signatureBubble: String?

    private static let canvas = CGSize(width: 300, height: 260)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.canvas.width, geometry.size.height / Self.canvas.height)
            effects
                .frame(width: Self.canvas.width, height: Self.canvas.height)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var effects: some View {
        let p = progress
        let fade = 1 - p
        ZStack {
            switch boop {
            case .squish:
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) / 6 * 2 * .pi - .pi / 2
                    Image(systemName: "sparkle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(fade)
                        .offset(x: cos(angle) * (90 + 60 * p), y: 20 + sin(angle) * (70 + 50 * p))
                }
            case .giggle:
                ForEach(0..<3, id: \.self) { i in
                    let rise = min(1, max(0, p * 1.4 - Double(i) * 0.15))
                    Image(systemName: i == 1 ? "music.note" : "music.quarternote.3")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.6, green: 0.85, blue: 1))
                        .opacity(rise > 0 ? 1 - rise : 0)
                        .offset(x: -110 + Double(i) * 26 + 8 * sin(rise * 8), y: -10 - 90 * rise)
                }
            case .spin:
                ForEach(0..<3, id: \.self) { i in
                    let angle = Double(i) / 3 * 2 * .pi + p * 12
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.yellow)
                        .opacity(p > 0.4 ? 1 : 0)
                        .offset(x: 54 * cos(angle), y: -78 + 14 * sin(angle))
                }
            case .love:
                ForEach(0..<5, id: \.self) { i in
                    let rise = min(1, max(0, p * 1.3 - Double(i) * 0.08))
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14 + Double(i % 3) * 5))
                        .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.6))
                        .opacity(rise > 0 ? 1 - rise * 0.9 : 0)
                        .offset(x: -70 + Double(i) * 35 + 10 * sin(rise * 6 + Double(i)), y: -40 - 110 * rise)
                }
            case .signature:
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) / 12 * 2 * .pi
                    let burst = min(1, p * 2)
                    Image(systemName: i % 3 == 0 ? "star.fill" : "sparkle")
                        .font(.system(size: 14 + Double(i % 3) * 4, weight: .bold))
                        .foregroundStyle(Color(hue: Double(i) / 12, saturation: 0.7, brightness: 1))
                        .opacity(1 - p)
                        .rotationEffect(.degrees(p * 180))
                        .offset(x: cos(angle) * (40 + 110 * burst), y: 10 + sin(angle) * (30 + 90 * burst))
                }
            case .grumpy:
                ForEach(0..<2, id: \.self) { i in
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 22 + Double(i) * 6))
                        .foregroundStyle(.white.opacity(0.75 * fade))
                        .offset(x: i == 0 ? -96 - 20 * p : 96 + 20 * p, y: -70 - 30 * p)
                }
            }
            BubbleLabel(text: boop == .signature ? signatureBubble ?? boop.bubble : boop.bubble, tint: boop == .grumpy ? .orange : boop == .love ? Color(red: 1, green: 0.7, blue: 0.8) : .white)
                .scaleEffect(min(1, p * 6))
                .offset(x: 100, y: -78)
        }
    }
}
