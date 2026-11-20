import BRBuddyCore
import Testing

struct KeepAwakeTests {
    @Test func activatesSwitchesAndReleases() {
        let keepAwake = KeepAwake()
        #expect(!keepAwake.isActive)

        #expect(keepAwake.activate(.systemOnly))
        #expect(keepAwake.mode == .systemOnly)

        #expect(keepAwake.activate(.systemAndDisplay))
        #expect(keepAwake.mode == .systemAndDisplay)

        keepAwake.release()
        #expect(!keepAwake.isActive)
        keepAwake.release()  // releasing twice is harmless
        #expect(!keepAwake.isActive)
    }
}
