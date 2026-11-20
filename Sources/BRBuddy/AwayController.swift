import AppKit
import BRBuddyCore
@preconcurrency import LocalAuthentication
import Observation
import SwiftUI

/// Runs BRB (Away mode): covers every display, blocks app switching and Force Quit, handles unlocking, and hands off
/// to the real macOS lock screen when `AwayPolicy` says so. Owned by `AppState`.
@MainActor
@Observable
final class AwayController {
    enum Phase: Equatable {
        /// Companion showing, waiting for someone to touch the Mac.
        case resting
        /// Someone touched the Mac: showing Touch ID and the password field.
        case unlocking
        /// Handing off to the real lock screen.
        case lockingForReal(AwayPolicy.Escalation)
    }

    private(set) var isAway = false
    private(set) var phase: Phase = .resting
    private(set) var awaySince = Date()
    private(set) var failedAttempts = 0
    private(set) var lastFailureMessage: String?
    /// True for a few seconds after a failed unlock, so the companion can react.
    private(set) var recentFailure = false
    private var lastFailureAt: Date?
    /// The Touch ID session shown inside the away window. Replaced each time unlocking starts.
    private(set) var authContext = LAContext()

    /// Called after BRB ends. `true` when it ended by handing off to the real lock screen.
    var onEnded: ((Bool) -> Void)?
    /// What the agents are doing, shown on the away screen. Set by `AppState`.
    var agents: AgentMonitor?
    /// Which companion to show. Set by `AppState`.
    var companions: CompanionLibrary?

    private var settings = AwaySettings.defaults
    private var windows: [AwayWindow] = []
    private var lastInput = Date()
    private var ticker: Timer?
    private var observers: [NSObjectProtocol] = []

    /// How long the unlock prompt stays up without input before going back to the companion.
    private let unlockPromptTimeout: TimeInterval = 30

    private static let lockedDownOptions: NSApplication.PresentationOptions = [
        .hideDock, .hideMenuBar, .disableProcessSwitching, .disableForceQuit,
        .disableSessionTermination, .disableHideApplication, .disableAppleMenu,
    ]

    var biometricsAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: Start and stop

    func start(settings: AwaySettings) {
        guard !isAway else { return }
        self.settings = settings
        isAway = true
        phase = .resting
        awaySince = Date()
        lastInput = Date()
        failedAttempts = 0
        lastFailureMessage = nil
        recentFailure = false

        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = Self.lockedDownOptions
        buildWindows()

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            MainActor.assumeIsolated { self?.reclaimFocus() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.buildWindows() }
        })
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stop(escalated: Bool) {
        guard isAway else { return }
        ticker?.invalidate()
        ticker = nil
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        authContext.invalidate()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        NSApp.presentationOptions = []
        isAway = false
        phase = .resting
        onEnded?(escalated)
    }

    // MARK: Windows and focus

    private func buildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.enumerated().map { index, screen in
            let window = AwayWindow(screen: screen)
            window.contentView = NSHostingView(rootView: AwayView(controller: self, isPrimary: index == 0))
            window.onUserInput = { [weak self] in self?.userTouched() }
            window.orderFrontRegardless()
            return window
        }
        windows.first?.makeKey()
    }

    /// Another app came to the front (an agent opened a browser, say): take the screen back.
    private func reclaimFocus() {
        guard isAway else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = Self.lockedDownOptions
        windows.forEach { $0.orderFrontRegardless() }
        windows.first?.makeKey()
    }

    // MARK: Unlocking

    private func userTouched() {
        lastInput = Date()
        if phase == .resting {
            authContext = LAContext()
            phase = .unlocking
        }
    }

    /// Starts Touch ID inside the away window. Called once the embedded Touch ID view is on screen.
    func evaluateTouchID() {
        let context = authContext
        let contextID = ObjectIdentifier(context)
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "unlock BRBuddy") { [weak self] success, error in
            let failed = (error as? LAError)?.code == .authenticationFailed
            Task { @MainActor in
                // Ignore results from a Touch ID session that has since been replaced.
                guard let self, ObjectIdentifier(self.authContext) == contextID else { return }
                if success {
                    self.stop(escalated: false)
                } else if failed {
                    self.recordFailure("Touch ID didn't match")
                }
            }
        }
    }

    /// Result of checking the typed password (done off the main thread by `UnlockPanel`).
    func passwordChecked(_ ok: Bool) {
        if ok { stop(escalated: false) } else { recordFailure("Wrong password") }
    }

    private func recordFailure(_ message: String) {
        failedAttempts += 1
        lastFailureMessage = message
        lastFailureAt = Date()
        recentFailure = true
        lastInput = Date()
        checkEscalation()
        if phase == .unlocking {
            // Fresh Touch ID session for the next try.
            authContext = LAContext()
        }
    }

    #if DEBUG
    /// Debug builds only: saves PNGs of the main away window resting and then unlocking, for checking the design
    /// without Screen Recording permission.
    func debugSnapshots(to folder: URL) async {
        guard let view = windows.first?.contentView else { return }
        func save(_ name: String) {
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: name))
        }
        try? await Task.sleep(for: .seconds(1.5))
        save("brb-resting.png")
        userTouched()
        try? await Task.sleep(for: .seconds(1.5))
        save("brb-unlocking.png")
    }
    #endif

    // MARK: Timers and escalation

    private func tick() {
        guard isAway else { return }
        checkEscalation()
        if recentFailure, let at = lastFailureAt, Date().timeIntervalSince(at) > 3 { recentFailure = false }
        if phase == .unlocking, Date().timeIntervalSince(lastInput) > unlockPromptTimeout {
            authContext.invalidate()
            phase = .resting
        }
    }

    private func checkEscalation() {
        if case .lockingForReal = phase { return }
        let escalation = AwayPolicy.escalation(failedAttempts: failedAttempts,
                                               awayFor: Date().timeIntervalSince(awaySince), settings: settings)
        guard escalation != .none else { return }
        phase = .lockingForReal(escalation)
        authContext.invalidate()
        // Show the message briefly, lock for real, then take the away screen down behind the lock screen.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            ScreenLocker.lockNow()
            try? await Task.sleep(for: .seconds(1.5))
            self.stop(escalated: true)
        }
    }
}
