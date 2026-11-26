import AppKit
import BRBuddyCore
import SwiftUI

/// Companion Studio: build a critter from the built-ins' parts, watch it react, boop it, and save it as a pack.
/// BRBuddy draws a saved design live from its `design.json`; the pack's spritesheets are for other pet apps and
/// sharing. Opened from Settings → Companion.
struct CompanionStudioView: View {
    let library: CompanionLibrary

    @State private var design = StudioDesign.starter
    /// The pack folder being edited; `nil` for a new design.
    @State private var editingFolder: String?
    @State private var mood: CompanionMood = .greeting
    @State private var useAfterSaving = true
    @State private var saving = false
    @State private var message: String?
    @State private var savedFolder: URL?

    private static let moods: [(CompanionMood, String)] = [
        (.resting, "Resting"), (.working, "Working"), (.waiting, "Waiting"), (.finished, "Done"), (.greeting, "Hi"),
        (.oops, "Oops"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            preview
                .frame(width: 340)
                .padding(20)
            Divider()
            Form {
                Section("Name and voice") {
                    TextField("Name", text: $design.name)
                    HStack {
                        Picker("Signature sound", selection: $design.signature) {
                            ForEach(BoopSignature.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Button { BoopPlayer.play(.signature, signature: design.signature) } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .help("Play it")
                    }
                    TextField("Signature line", text: $design.bubble)
                }
                Section("Body") {
                    Picker("Shape", selection: $design.body) {
                        Text("Round").tag(StudioDesign.Body.round)
                        Text("Pebble").tag(StudioDesign.Body.pebble)
                        Text("Hexagon").tag(StudioDesign.Body.hex)
                        Text("Cloud").tag(StudioDesign.Body.cloud)
                        Text("Spiky").tag(StudioDesign.Body.spiky)
                    }
                    ColorPicker("Top colour", selection: color($design.top), supportsOpacity: false)
                    ColorPicker("Bottom colour", selection: color($design.bottom), supportsOpacity: false)
                    Toggle("Floats", isOn: $design.floats)
                }
                Section("Ears and extras") {
                    Picker("Ears", selection: $design.ears) {
                        Text("None").tag(StudioDesign.Ears.none)
                        Text("Round").tag(StudioDesign.Ears.round)
                        Text("Pointy").tag(StudioDesign.Ears.pointy)
                    }
                    ColorPicker("Ear colour", selection: color($design.earColor), supportsOpacity: false)
                        .disabled(design.ears == .none)
                    Picker("Extra", selection: $design.accent) {
                        Text("None").tag(StudioDesign.Accent.none)
                        Text("Sprout").tag(StudioDesign.Accent.sprout)
                        Text("Star freckles").tag(StudioDesign.Accent.starFreckles)
                        Text("Wisps").tag(StudioDesign.Accent.wisps)
                        Text("Snaggle tooth").tag(StudioDesign.Accent.snaggleTooth)
                    }
                    ColorPicker("Extra colour", selection: color($design.accentColor), supportsOpacity: false)
                        .disabled(design.accent == .none)
                }
                Section("Face") {
                    Picker("Mouth", selection: $design.mouth) {
                        Text("Standard").tag(StudioDesign.Mouth.standard)
                        Text("Cat (ω)").tag(StudioDesign.Mouth.cat)
                        Text("Big grin").tag(StudioDesign.Mouth.grin)
                        Text("Tongue out").tag(StudioDesign.Mouth.blep)
                        Text("Fangs").tag(StudioDesign.Mouth.fangs)
                        Text("Beak").tag(StudioDesign.Mouth.beak)
                    }
                    LabeledContent("Mouth size") {
                        Slider(value: $design.mouthSize, in: StudioDesign.mouthSizes) {
                            EmptyView()
                        } minimumValueLabel: {
                            Image(systemName: "minus").font(.caption)
                        } maximumValueLabel: {
                            Image(systemName: "plus").font(.caption)
                        }
                        .frame(width: 170)
                    }
                    Toggle("Light eyes (for dark bodies)", isOn: $design.lightInk)
                    Toggle("Blush", isOn: $design.blush)
                    ColorPicker("Blush colour", selection: color($design.blushColor), supportsOpacity: false)
                        .disabled(!design.blush)
                    Toggle("One eye bigger", isOn: $design.lopsided)
                }
            }
            .formStyle(.grouped)
            .frame(width: 380)
        }
        .frame(height: 560)
        .onAppear { NSApp.activate() }
    }

    // MARK: Preview and actions

    private var preview: some View {
        VStack(spacing: 14) {
            HStack {
                Menu {
                    Button("New design") { open(.starter, folder: nil) }
                    let mine = library.packs.filter { $0.studioDesign != nil }
                    if !mine.isEmpty {
                        Divider()
                        ForEach(mine) { pack in
                            Button("Edit \(pack.displayName)") { open(pack.studioDesign!, folder: pack.id) }
                        }
                    }
                } label: {
                    Label(editingFolder == nil ? "New design" : "Editing \(design.name)", systemImage: "pencil")
                }
                .fixedSize()
                Spacer()
                Button {
                    var generator = SystemRandomNumberGenerator()
                    let name = design.name
                    design = .random(using: &generator)
                    if editingFolder != nil { design.name = name }
                } label: {
                    Label("Surprise me", systemImage: "dice")
                }
            }

            CompanionView(library: library, mood: mood, agent: nil, canBoop: true, studio: design.tidied)
                .frame(width: 300, height: 260)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.09, green: 0.07, blue: 0.13)))

            Picker("Mood", selection: $mood) {
                ForEach(Self.moods, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("Click it to boop. Every companion gets five shared boops plus its signature one.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Toggle("Use it as my companion", isOn: $useAfterSaving)
            HStack {
                if let savedFolder {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([savedFolder]) }
                }
                Spacer()
                if saving { ProgressView().controlSize(.small) }
                Button(editingFolder == nil ? "Save companion" : "Save changes") { Task { await save() } }
                    .keyboardShortcut("s")
                    .buttonStyle(.borderedProminent)
                    .disabled(saving)
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func open(_ design: StudioDesign, folder: String?) {
        self.design = design
        editingFolder = folder
        savedFolder = nil
        message = nil
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let final = design.tidied
        design = final
        let root = CompanionPackLibrary.folder
        let folder = StudioPackWriter.folder(for: final, in: root, preferred: editingFolder)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let sheet = try await StudioSheetRenderer.render(final, still: false)
            let stillSheet = try await StudioSheetRenderer.render(final, still: true)
            try StudioPackWriter.write(final, sheet: sheet, stillSheet: stillSheet, to: folder)
            library.reload()
            editingFolder = folder.lastPathComponent
            savedFolder = folder
            if useAfterSaving { library.choice = .pack(folder.lastPathComponent) }
            message = "Saved \(final.name). Share it by sending the folder; it works in other pet apps too."
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }

    /// A SwiftUI colour binding over a design colour.
    private func color(_ binding: Binding<StudioColor>) -> Binding<Color> {
        Binding {
            Color(red: binding.wrappedValue.red, green: binding.wrappedValue.green, blue: binding.wrappedValue.blue)
        } set: { newValue in
            guard let rgb = NSColor(newValue).usingColorSpace(.sRGB) else { return }
            binding.wrappedValue = StudioColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
        }
    }
}

/// Draws a Studio design's spritesheets in the Codex pet layout: 8 frames per mood row, 192 × 208 cells.
@MainActor
enum StudioSheetRenderer {
    enum RenderError: Error { case noContext, noImage }

    static let cell = CGSize(width: CompanionPack.cellWidth, height: CompanionPack.cellHeight)
    /// Codex rows 0–8: idle, run right, run left, waving, jumping, failed, waiting, running, review.
    static let rows: [CompanionMood] = [.resting, .working, .working, .greeting, .finished, .oops, .waiting, .working, .resting]

    /// How many seconds of the live animation each row's eight frames cover, so its main motion loops.
    static func loopLength(_ mood: CompanionMood) -> Double {
        switch mood {
        case .resting: 2 * .pi / 1.6
        case .working: .pi / 9 * 3
        case .waiting: .pi / 4 * 2
        case .finished: 2 * .pi / 3.2
        case .greeting: 2 * .pi / 2.5
        case .oops: .pi
        }
    }

    /// PNG data for the whole sheet. `still` draws the body held still with only the face moving.
    static func render(_ design: StudioDesign, still: Bool) async throws -> Data {
        let columns = CompanionPack.columns
        let width = Int(cell.width) * columns, height = Int(cell.height) * rows.count
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RenderError.noContext }
        let critter = CritterDesign(studio: design)
        for (row, mood) in rows.enumerated() {
            for frame in 0..<columns {
                // Start well past zero, and away from a blink (every 4 s), so the timers are mid-cycle as they are live.
                let t = 41 + Double(frame) / Double(columns) * loopLength(mood)
                let view = CritterView(design: critter, mood: mood, still: still, fixedTime: t)
                    .frame(width: cell.width, height: cell.width * 260 / 300)
                    .frame(width: cell.width, height: cell.height, alignment: .bottom)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                guard let image = renderer.cgImage else { throw RenderError.noImage }
                context.draw(image, in: CGRect(x: CGFloat(frame) * cell.width, y: CGFloat(height) - CGFloat(row + 1) * cell.height,
                                               width: cell.width, height: cell.height))
            }
            await Task.yield()  // keep the window responsive between rows
        }
        guard let sheet = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: sheet).representation(using: .png, properties: [:]) else { throw RenderError.noImage }
        return png
    }
}
