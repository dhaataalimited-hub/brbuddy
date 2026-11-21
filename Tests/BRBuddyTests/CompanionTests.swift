@testable import BRBuddyCore
import CoreGraphics
import Foundation
import IOKit.ps
import ImageIO
import Testing
import UniformTypeIdentifiers

struct CompanionMoodTests {
    let session = AgentTracker.Session(agent: .claude, id: "s", cwd: nil, activity: .working, lastEvent: Date())

    @Test func awayScreenEventsWinOverAgentState() {
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .none) == .resting)
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .working(session)) == .working)
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .waiting(session)) == .waiting)
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .finished(session)) == .finished)
        #expect(CompanionMood.current(isUnlocking: true, recentFailure: false, lockingForReal: false, agent: .waiting(session)) == .greeting)
        #expect(CompanionMood.current(isUnlocking: true, recentFailure: true, lockingForReal: false, agent: .none) == .oops)
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: true, agent: .none) == .oops)
    }
}

struct CompanionCatalogTests {
    @Test func everyAgentHasItsOwnBuiltIn() {
        let matched = Set(AgentKind.allCases.map { CompanionCatalog.builtIn(for: $0).id })
        #expect(matched.count == AgentKind.allCases.count)
    }

    @Test func choiceRoundTripsThroughStorage() {
        for choice in [CompanionCatalog.Choice.matchAgent, .builtIn("comet"), .pack("my-cat")] {
            #expect(CompanionCatalog.Choice(storageValue: choice.storageValue) == choice)
        }
        #expect(CompanionCatalog.Choice(storageValue: nil) == .matchAgent)
    }

    @Test func resolvesChoicesWithFallbacks() {
        let packs: [String: [AgentKind]] = ["cat": [.codex], "dog": []]
        #expect(CompanionCatalog.resolve(.matchAgent, agent: nil, availablePacks: [:]) == .builtIn(CompanionCatalog.defaultBuiltIn))
        #expect(CompanionCatalog.resolve(.matchAgent, agent: .gemini, availablePacks: packs) == .builtIn(CompanionCatalog.builtIn(for: .gemini)))
        #expect(CompanionCatalog.resolve(.matchAgent, agent: .codex, availablePacks: packs) == .pack("cat"))
        #expect(CompanionCatalog.resolve(.pack("dog"), agent: .codex, availablePacks: packs) == .pack("dog"))
        #expect(CompanionCatalog.resolve(.pack("gone"), agent: .grok, availablePacks: packs) == .builtIn(CompanionCatalog.builtIn(for: .grok)))
        #expect(CompanionCatalog.resolve(.builtIn("drift"), agent: .claude, availablePacks: packs) == .builtIn(CompanionCatalog.builtIn(id: "drift")!))
    }
}

struct CompanionPackTests {
    /// Writes a pack whose idle row has 3 drawn frames and whose other rows are blank.
    func makePack(width: Int = 1536, height: Int = 1872, manifest: String? = nil) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "brb-pack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0.5, blue: 0.3, alpha: 1))
        for column in 0..<3 {  // Row 0 is the top row; CGContext's origin is bottom-left.
            context.fill(CGRect(x: column * 192 + 40, y: height - 208 + 40, width: 100, height: 120))
        }
        let image = try #require(context.makeImage())
        let url = folder.appending(path: "spritesheet.png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        let json = manifest ?? #"{"id":"test","displayName":"Test Pup","spritesheetPath":"spritesheet.png","license":"CC0-1.0","agents":["codex","nope"]}"#
        try Data(json.utf8).write(to: folder.appending(path: "pet.json"))
        return folder
    }

    @Test func loadsAValidPackAndCutsFrames() throws {
        let folder = try makePack()
        defer { try? FileManager.default.removeItem(at: folder) }
        let pack = try CompanionPack.load(from: folder)
        #expect(pack.displayName == "Test Pup" && pack.license == "CC0-1.0" && pack.spriteVersion == 1)
        #expect(pack.agents == [.codex])
        let frames = pack.frames()
        #expect(frames[.resting]?.count == 3)
        #expect(frames[.working]?.isEmpty == true)
    }

    @Test func readsAnOptionalStillSheet() throws {
        let folder = try makePack(manifest: #"{"spritesheetPath":"spritesheet.png","stillSpritesheetPath":"spritesheet.png"}"#)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pack = try CompanionPack.load(from: folder)
        #expect(pack.stillSpritesheetURL != nil)
        #expect(pack.frames(still: true)[.resting]?.count == 3)

        let missing = try makePack(manifest: #"{"spritesheetPath":"spritesheet.png","stillSpritesheetPath":"../nope.png"}"#)
        defer { try? FileManager.default.removeItem(at: missing) }
        #expect(try CompanionPack.load(from: missing).stillSpritesheetURL == nil)  // a bad still sheet is ignored
    }

    @Test func readsASignatureBoop() throws {
        let folder = try makePack(manifest: #"{"spritesheetPath":"spritesheet.png","boopSignature":"clickWheel","boopBubble":"click click"}"#)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pack = try CompanionPack.load(from: folder)
        #expect(pack.boopSignature == .clickWheel && pack.boopBubble == "click click")
        let unknown = try makePack(manifest: #"{"spritesheetPath":"spritesheet.png","boopSignature":"kazoo"}"#)
        defer { try? FileManager.default.removeItem(at: unknown) }
        #expect(try CompanionPack.load(from: unknown).boopSignature == nil)
    }

    @Test func rejectsBadPacks() throws {
        let wrongSize = try makePack(width: 800, height: 600)
        defer { try? FileManager.default.removeItem(at: wrongSize) }
        #expect(throws: CompanionPack.LoadError.wrongSize(width: 800, height: 600)) { try CompanionPack.load(from: wrongSize) }

        let escaping = try makePack(manifest: #"{"spritesheetPath":"../../etc/passwd"}"#)
        defer { try? FileManager.default.removeItem(at: escaping) }
        #expect(throws: CompanionPack.LoadError.self) { try CompanionPack.load(from: escaping) }

        let empty = FileManager.default.temporaryDirectory.appending(path: "brb-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        #expect(throws: CompanionPack.LoadError.missingManifest) { try CompanionPack.load(from: empty) }
    }

    @Test func importsIntoTheLibraryAndScansIt() throws {
        let source = try makePack()
        let root = FileManager.default.temporaryDirectory.appending(path: "brb-lib-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: root) }
        try CompanionPackLibrary.importPack(from: source, into: root)
        try FileManager.default.createDirectory(at: root.appending(path: "broken"), withIntermediateDirectories: true)
        let scan = CompanionPackLibrary.scan(root)
        #expect(scan.packs.map(\.id) == [source.lastPathComponent])
        #expect(scan.problems.map(\.folder) == ["broken"])
    }
}

struct BatteryTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func readsAnInternalBattery() {
        let description: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true, kIOPSCurrentCapacityKey: 27,
            kIOPSMaxCapacityKey: 100, kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue, kIOPSIsChargingKey: false,
            kIOPSTimeToEmptyKey: 81, kIOPSTimeToFullChargeKey: -1,
        ]
        let status = BatteryStatus.parse(description, lowPowerMode: false)
        #expect(status == BatteryStatus(percent: 27, isPluggedIn: false, isCharging: false, minutesRemaining: 81))
    }

    @Test func stillCalculatingHasNoTimeAndUPSIsIgnored() {
        let charging: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: 50, kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: true, kIOPSTimeToFullChargeKey: -1,
        ]
        #expect(BatteryStatus.parse(charging, lowPowerMode: true)?.minutesRemaining == nil)
        #expect(BatteryStatus.parse(charging, lowPowerMode: true)?.isLowPowerMode == true)
        let ups: [String: Any] = [kIOPSTypeKey: kIOPSUPSType, kIOPSCurrentCapacityKey: 50]
        #expect(BatteryStatus.parse(ups, lowPowerMode: false) == nil)
    }

    @Test func reactionsFollowTheBattery() {
        func reaction(_ status: BatteryStatus?) -> BatteryReaction { .current(status, lastChange: nil) }
        #expect(reaction(nil) == .none)
        #expect(reaction(BatteryStatus(percent: 80, isPluggedIn: false, isCharging: false)) == .none)
        #expect(reaction(BatteryStatus(percent: 20, isPluggedIn: false, isCharging: false)) == .low)
        #expect(reaction(BatteryStatus(percent: 9, isPluggedIn: false, isCharging: false, isLowPowerMode: true)) == .critical)
        #expect(reaction(BatteryStatus(percent: 60, isPluggedIn: false, isCharging: false, isLowPowerMode: true)) == .lowPower)
        #expect(reaction(BatteryStatus(percent: 9, isPluggedIn: true, isCharging: true)) == .charging)
        #expect(reaction(BatteryStatus(percent: 100, isPluggedIn: true, isCharging: false)) == .full)
    }

    @Test func plugAndUnplugFlourishThenSettle() {
        var watch = BatteryWatch()
        watch.update(BatteryStatus(percent: 15, isPluggedIn: false, isCharging: false), now: start)
        #expect(watch.reaction(now: start) == .low)  // the first reading isn't a change
        watch.update(BatteryStatus(percent: 15, isPluggedIn: true, isCharging: true), now: start + 10)
        #expect(watch.reaction(now: start + 12) == .pluggedIn)
        #expect(watch.reaction(now: start + 17) == .charging)
        watch.update(BatteryStatus(percent: 16, isPluggedIn: false, isCharging: false), now: start + 20)
        #expect(watch.reaction(now: start + 21) == .unplugged)
        #expect(watch.reaction(now: start + 30) == .low)
    }

    @Test func flourishesShowOnTheCompanionButPeopleWin() {
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .none,
                                      battery: .pluggedIn) == .finished)
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .none,
                                      battery: .unplugged) == .oops)
        #expect(CompanionMood.current(isUnlocking: true, recentFailure: false, lockingForReal: false, agent: .none,
                                      battery: .pluggedIn) == .greeting)
        #expect(CompanionMood.current(isUnlocking: false, recentFailure: false, lockingForReal: false, agent: .none,
                                      battery: .low) == .resting)
    }
}

struct BoopTests {
    /// A repeatable generator so shuffles are the same every run.
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func everyFriendlyBoopComesUpBeforeRepeatsAndNeverTwiceInARow() {
        var picker = BoopPicker()
        var generator = Seeded(state: 42)
        var picks: [Boop] = []
        for i in 0..<15 { picks.append(picker.next(now: start + Double(i) * 10, using: &generator)) }
        #expect(BoopPicker.friendly.count == 5 && BoopPicker.friendly.contains(.signature))
        #expect(Set(picks.prefix(5)) == Set(BoopPicker.friendly))
        #expect(Set(picks[5..<10]) == Set(BoopPicker.friendly))
        #expect(!zip(picks, picks.dropFirst()).contains { $0 == $1 })
        #expect(!picks.contains(.grumpy))
    }

    @Test func boopingTooFastMakesItGrumpy() {
        var picker = BoopPicker()
        var generator = Seeded(state: 7)
        let fast = (0..<6).map { picker.next(now: start + Double($0) * 0.4, using: &generator) }
        #expect(!fast.prefix(4).contains(.grumpy))
        #expect(fast[4] == .grumpy && fast[5] == .grumpy)
        #expect(picker.next(now: start + 30, using: &generator) != .grumpy)  // calms down after a rest
    }

    @Test func progressRunsZeroToOneThenEnds() {
        let event = BoopEvent(.squish, at: start)
        #expect(event.progress(at: start) == 0)
        #expect(event.progress(at: start + Boop.squish.duration / 2) == 0.5)
        #expect(event.progress(at: start + 5) == nil)
    }

    @Test func everySoundIsAShortValidWAV() {
        let sounds = Boop.allCases.map { BoopSound.wav(for: $0) }
            + BoopSignature.allCases.map { BoopSound.wav(for: .signature, signature: $0) }
        for wav in sounds {
            #expect(wav.prefix(4) == Data("RIFF".utf8))
            #expect(wav.count > 44 + 2_000)  // header plus some audio
            #expect(wav.count < 44 + 44_100 * 2 * 2)  // under two seconds
        }
    }

    @Test func everyBuiltInHasItsOwnSignature() {
        let signatures = CompanionCatalog.builtIns.map { BoopSignature.builtIn($0.id).signature }
        #expect(Set(signatures).count == CompanionCatalog.builtIns.count)
        #expect(!signatures.contains(.sparkle))
        let sounds = Set(BoopSignature.allCases.map { BoopSound.wav(for: .signature, signature: $0) })
        #expect(sounds.count == BoopSignature.allCases.count)  // all different
    }
}

struct StudioDesignTests {
    @Test func coloursRoundTripThroughHex() throws {
        let color = try #require(StudioColor(hex: "#FFB38A"))
        #expect(color.hex == "#FFB38A")
        #expect(StudioColor(hex: "nope") == nil)
        #expect(StudioColor(hue: 0, saturation: 1, brightness: 1).hex == "#FF0000")
        #expect(StudioColor(hue: 1.0 / 3, saturation: 1, brightness: 1).hex == "#00FF00")
    }

    @Test func designRoundTripsThroughJSONWithHexColours() throws {
        let data = try JSONEncoder().encode(StudioDesign.starter)
        #expect(String(decoding: data, as: UTF8.self).contains("\"#FFB38A\""))
        #expect(try JSONDecoder().decode(StudioDesign.self, from: data) == .starter)
    }

    @Test func mouthsRoundTripAndOldDesignsGetTheStandardOne() throws {
        var design = StudioDesign.starter
        design.mouth = .beak
        design.mouthSize = 1.3
        let data = try JSONEncoder().encode(design)
        #expect(try JSONDecoder().decode(StudioDesign.self, from: data) == design)

        // A design saved before mouths existed.
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(StudioDesign.starter)) as! [String: Any]
        old["mouth"] = nil
        old["mouthSize"] = nil
        let loaded = try JSONDecoder().decode(StudioDesign.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(loaded.mouth == .standard && loaded.mouthSize == 1)

        design.mouthSize = 9
        #expect(design.tidied.mouthSize == StudioDesign.mouthSizes.upperBound)
    }

    @Test func randomDesignsVaryAndAreTidy() {
        var generator = BoopTests.Seeded(state: 3)
        let designs = (0..<8).map { _ in StudioDesign.random(using: &generator) }
        #expect(Set(designs.map(\.top)).count > 4)
        #expect(designs.allSatisfy { $0 == $0.tidied })
    }

    @Test func folderNamesAreSafeSlugs() {
        var design = StudioDesign.starter
        design.name = "Mr. Fluffy  Pants!"
        #expect(design.folderName == "mr-fluffy-pants")
        design.name = "../../etc"
        #expect(design.folderName == "etc")
        design.name = "🐱"
        #expect(design.folderName == "studio-companion")
        design.name = "   "
        #expect(design.tidied.name == "Buddy")
    }

    @Test func writesAPackThatLoadsAsALiveDesign() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "brb-studio-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var design = StudioDesign.starter
        design.signature = .zoom
        let sheet = try blankSheet()
        let folder = StudioPackWriter.folder(for: design, in: root)
        try StudioPackWriter.write(design, sheet: sheet, stillSheet: sheet, to: folder)
        #expect(folder.lastPathComponent == "buddy")
        #expect(StudioPackWriter.folder(for: design, in: root).lastPathComponent == "buddy-2")  // name taken
        #expect(StudioPackWriter.folder(for: design, in: root, preferred: "buddy").lastPathComponent == "buddy")

        let pack = try CompanionPack.load(from: folder)
        #expect(pack.studioDesign == design)
        #expect(pack.boopSignature == .zoom && pack.boopBubble == design.bubble)
        #expect(pack.stillSpritesheetURL != nil)
    }

    /// A transparent 1536 × 1872 PNG.
    private func blankSheet() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 1536, height: 1872, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
