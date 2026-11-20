import BRBuddyCore
import SwiftUI

/// Draws a `TerminalMirror.Snapshot`: a dark, read-only panel showing as many of the latest lines as fit. There's no
/// input path at all; it's just text.
struct TerminalMirrorView: View {
    let snapshot: TerminalMirror.Snapshot
    var fontSize: CGFloat = 13

    private var lineHeight: CGFloat { fontSize * 1.32 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                Text(snapshot.source)
                Spacer()
                Text("read-only")
            }
            .font(.system(size: fontSize - 2, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))

            GeometryReader { geometry in
                let fitting = max(1, Int(geometry.size.height / lineHeight))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(trimmedLines.suffix(fitting).enumerated()), id: \.offset) { _, line in
                        Text(attributed(line))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: lineHeight, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
    }

    /// Without trailing blank lines (tmux pads panes to their height).
    private var trimmedLines: [TerminalLine] {
        var lines = snapshot.lines
        while let last = lines.last, last.allSatisfy({ $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
            lines.removeLast()
        }
        return lines
    }

    private func attributed(_ line: TerminalLine) -> AttributedString {
        var result = AttributedString()
        for run in line {
            var piece = AttributedString(run.text)
            var fg = color(run.style.foreground) ?? Color(white: 0.86)
            var bg = color(run.style.background)
            if run.style.inverse { (fg, bg) = (bg ?? Color(white: 0.1), fg) }
            piece.foregroundColor = run.style.dim ? fg.opacity(0.55) : fg
            if let bg { piece.backgroundColor = bg }
            let font = Font.system(size: fontSize, weight: run.style.bold ? .bold : .regular, design: .monospaced)
            piece.font = run.style.italic ? font.italic() : font
            if run.style.underline { piece.underlineStyle = .single }
            result += piece
        }
        return result
    }

    private func color(_ terminal: TerminalColor) -> Color? {
        terminal.components.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
    }
}
