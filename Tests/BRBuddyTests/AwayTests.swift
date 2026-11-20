import BRBuddyCore
import Foundation
import Testing

struct AwayPolicyTests {
    let settings = AwaySettings.defaults  // 3 idle minutes, 3 attempts, 60 minutes

    @Test func autoStartsOnlyWhenIdleLongEnoughWithKeepAwakeOn() {
        #expect(!AwayPolicy.shouldAutoStart(idleSeconds: 179, keepAwakeOn: true, isAway: false, settings: settings))
        #expect(AwayPolicy.shouldAutoStart(idleSeconds: 180, keepAwakeOn: true, isAway: false, settings: settings))
        #expect(!AwayPolicy.shouldAutoStart(idleSeconds: 999, keepAwakeOn: false, isAway: false, settings: settings))
        #expect(!AwayPolicy.shouldAutoStart(idleSeconds: 999, keepAwakeOn: true, isAway: true, settings: settings))
        var off = settings
        off.autoStartEnabled = false
        #expect(!AwayPolicy.shouldAutoStart(idleSeconds: 999, keepAwakeOn: true, isAway: false, settings: off))
    }

    @Test func escalatesOnFailuresOrTime() {
        #expect(AwayPolicy.escalation(failedAttempts: 2, awayFor: 0, settings: settings) == .none)
        #expect(AwayPolicy.escalation(failedAttempts: 3, awayFor: 0, settings: settings) == .tooManyFailedAttempts)
        #expect(AwayPolicy.escalation(failedAttempts: 0, awayFor: 3599, settings: settings) == .none)
        #expect(AwayPolicy.escalation(failedAttempts: 0, awayFor: 3600, settings: settings) == .awayTooLong)
        var never = settings
        never.escalateAfterMinutes = 0
        #expect(AwayPolicy.escalation(failedAttempts: 0, awayFor: 99_999, settings: never) == .none)
    }
}

struct AwaySettingsTests {
    @Test func roundTripsAndClamps() throws {
        let store = try #require(UserDefaults(suiteName: "brbuddy.tests.\(UUID().uuidString)"))
        #expect(AwaySettings.load(from: store) == .defaults)

        let custom = AwaySettings(autoStartEnabled: false, idleMinutes: 10, maxFailedAttempts: 5, escalateAfterMinutes: 0)
        custom.save(to: store)
        #expect(AwaySettings.load(from: store) == custom)

        store.set(0, forKey: "away.idleMinutes")
        store.set(500, forKey: "away.maxFailedAttempts")
        let clamped = AwaySettings.load(from: store)
        #expect(clamped.idleMinutes == 1)
        #expect(clamped.maxFailedAttempts == 10)
    }
}

struct SystemHookTests {
    @Test func idleCounterIsReadable() {
        #expect(IdleMonitor.secondsSinceLastInput() >= 0)
    }

    /// Only checks the private lock call resolves on this macOS. Never calls it.
    @Test func realLockCallIsAvailable() {
        #expect(ScreenLocker.canLockImmediately)
    }

    /// Only looks up the user record. Never checks a password (a wrong one counts against the account).
    @Test func currentUserRecordIsFound() {
        #expect(PasswordVerifier.currentUserRecord() != nil)
    }
}
