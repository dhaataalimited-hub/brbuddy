import BRBuddyCore
import Testing

struct AppVersionTests {
    @Test func showsTheVersionAndBuild() {
        #expect(AppVersion.label(info: ["CFBundleShortVersionString": "0.1.3", "CFBundleVersion": "12"]) == "0.1.3 (12)")
    }

    @Test func leavesOutABuildThatMatchesOrIsMissing() {
        #expect(AppVersion.label(info: ["CFBundleShortVersionString": "0.1.3", "CFBundleVersion": "0.1.3"]) == "0.1.3")
        #expect(AppVersion.label(info: ["CFBundleShortVersionString": "0.1.3"]) == "0.1.3")
    }

    @Test func callsACopyWithNoVersionADevelopmentBuild() {
        #expect(AppVersion.label(info: nil) == "Development build")
        #expect(AppVersion.label(info: [:]) == "Development build")
    }
}
