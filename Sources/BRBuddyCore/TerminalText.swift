import Foundation

/// A colour as a terminal describes it.
public enum TerminalColor: Equatable, Sendable {
    case `default`
    /// 0–15 are the standard and bright colours; 16–255 the xterm cube and greys.
    case indexed(UInt8)
    case rgb(UInt8, UInt8, UInt8)

    /// The colour as RGB (0–1), using the xterm palette. nil for the default colour.
    public var components: (red: Double, green: Double, blue: Double)? {
        switch self {
        case .default: return nil
        case .rgb(let r, let g, let b): return (Double(r) / 255, Double(g) / 255, Double(b) / 255)
        case .indexed(let i):
            let base: [(Int, Int, Int)] = [
                (0, 0, 0), (205, 49, 49), (13, 188, 121), (229, 229, 16), (36, 114, 200), (188, 63, 188), (17, 168, 205), (229, 229, 229),
                (102, 102, 102), (241, 76, 76), (35, 209, 139), (245, 245, 67), (59, 142, 234), (214, 112, 214), (41, 184, 219), (255, 255, 255),
            ]
            if i < 16 { let c = base[Int(i)]; return (Double(c.0) / 255, Double(c.1) / 255, Double(c.2) / 255) }
            if i < 232 {
                let n = Int(i) - 16
                let level = { (v: Int) -> Double in v == 0 ? 0 : Double(55 + v * 40) / 255 }
                return (level(n / 36), level((n / 6) % 6), level(n % 6))
            }
            let grey = Double(8 + (Int(i) - 232) * 10) / 255
            return (grey, grey, grey)
        }
    }
}

/// How a run of text is drawn.
public struct TerminalStyle: Equatable, Sendable {
    public var foreground: TerminalColor = .default
    public var background: TerminalColor = .default
    public var bold = false
    public var dim = false
    public var italic = false
    public var underline = false
    public var inverse = false

    public init() {}
}

/// Text in one style.
public struct TerminalRun: Equatable, Sendable {
    public var text: String
    public var style: TerminalStyle

    public init(_ text: String, style: TerminalStyle = TerminalStyle()) {
        self.text = text
        self.style = style
    }
}

public typealias TerminalLine = [TerminalRun]

/// Turns terminal output that uses colour codes (SGR, as `tmux capture-pane -e` produces) into styled lines. Other
/// escape sequences (cursor movement, titles) are dropped, so the result is always safe, display-only text.
public enum ANSIParser {
    public static func parse(_ text: String) -> [TerminalLine] {
        var lines: [TerminalLine] = []
        var current: TerminalLine = []
        var style = TerminalStyle()
        var buffer = ""

        func flush() {
            if !buffer.isEmpty { current.append(TerminalRun(buffer, style: style)); buffer = "" }
        }

        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            switch c {
            case "\u{1B}":
                flush()
                i += 1
                guard i < scalars.count else { break }
                if scalars[i] == "[" {  // CSI: parameters then a final byte in @...~
                    i += 1
                    var params = ""
                    while i < scalars.count, !(0x40...0x7E).contains(scalars[i].value) {
                        params.unicodeScalars.append(scalars[i]); i += 1
                    }
                    if i < scalars.count, scalars[i] == "m" { apply(params, to: &style) }
                } else if scalars[i] == "]" {  // OSC: until BEL or ESC \
                    while i < scalars.count, scalars[i] != "\u{07}" {
                        if scalars[i] == "\u{1B}", i + 1 < scalars.count, scalars[i + 1] == "\\" { i += 1; break }
                        i += 1
                    }
                }
            case "\n":
                flush()
                lines.append(current)
                current = []
            case "\r", "\u{07}":
                break
            case "\t":
                buffer += "    "
            default:
                if c.value >= 0x20 { buffer.unicodeScalars.append(c) }
            }
            i += 1
        }
        flush()
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    static func apply(_ params: String, to style: inout TerminalStyle) {
        var codes = params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        if codes.isEmpty { codes = [0] }
        var i = 0
        func color(_ codes: [Int], _ i: inout Int) -> TerminalColor? {
            guard i + 1 < codes.count else { return nil }
            if codes[i + 1] == 5, i + 2 < codes.count { defer { i += 2 }; return .indexed(UInt8(clamping: codes[i + 2])) }
            if codes[i + 1] == 2, i + 4 < codes.count {
                defer { i += 4 }
                return .rgb(UInt8(clamping: codes[i + 2]), UInt8(clamping: codes[i + 3]), UInt8(clamping: codes[i + 4]))
            }
            return nil
        }
        while i < codes.count {
            let code = codes[i]
            switch code {
            case 0: style = TerminalStyle()
            case 1: style.bold = true
            case 2: style.dim = true
            case 3: style.italic = true
            case 4: style.underline = true
            case 7: style.inverse = true
            case 22: style.bold = false; style.dim = false
            case 23: style.italic = false
            case 24: style.underline = false
            case 27: style.inverse = false
            case 30...37: style.foreground = .indexed(UInt8(code - 30))
            case 38: if let c = color(codes, &i) { style.foreground = c }
            case 39: style.foreground = .default
            case 40...47: style.background = .indexed(UInt8(code - 40))
            case 48: if let c = color(codes, &i) { style.background = c }
            case 49: style.background = .default
            case 90...97: style.foreground = .indexed(UInt8(code - 90 + 8))
            case 100...107: style.background = .indexed(UInt8(code - 100 + 8))
            default: break
            }
            i += 1
        }
    }

    /// Plain lines (from the Accessibility source) as unstyled terminal lines.
    public static func plain(_ text: String) -> [TerminalLine] {
        text.components(separatedBy: "\n").map { $0.isEmpty ? [] : [TerminalRun($0.replacingOccurrences(of: "\t", with: "    "))] }
    }
}
