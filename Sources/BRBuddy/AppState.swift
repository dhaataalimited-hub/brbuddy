import BRBuddyCore
import Foundation
import KeyboardShortcuts
import Observation
import ServiceManagement

extension KeyboardShortcuts.Name {
    /// Global shortcut that starts BRB right away. Default ⌃⌥⌘B.
    static let brbNow = Self("brbNow", initial: .init(.b, modifiers: [.control, .option, .command]))
}

/// The app's single source of truth for what BRBuddy is doing right now. Created once by `AppDelegate`.
///
/// Owns keep-awake, the away controller and the idle check. While keep-awake is on and auto-start is enabled it
/// also keeps the display on, so macOS's own screen saver or display sleep can't kick in before BRB does.
@MainActor
@Observable
final class AppState {
    private let keepAwake = KeepAwake()
    let away = AwayController()

    private(set) var isKeepingAwake = false
    private(set) var launchAtLoginError: String?

    var settings: AwaySettings {
        didSet {
            settings.save()
            applyKeepAwakeMode()
        }
    }

    private var idleTimer: Timer?

    init() {
        settings = AwaySettings.load()
        away.onEnded = { [weak self] _ in self?.applyKeepAwakeMode() }
        KeyboardShortcuts.onKeyUp(for: .brbNow) { [weak self] in self?.startAway() }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
    }

    // MARK: Keep awake

    func setKeepingAwake(_ on: Bool) {
        isKeepingAwake = on
        applyKeepAwakeMode()
    }

    private func applyKeepAwakeMode() {
        if away.isAway {
            keepAwake.activate(.systemAndDisplay, reason: "BRBuddy is showing the away screen")
        } else if isKeepingAwake {
            let mode: KeepAwake.Mode = settings.autoStartEnabled ? .systemAndDisplay : .systemOnly
            if !keepAwake.activate(mode) { isKeepingAwake = false }
        } else {
            keepAwake.release()
        }
    }

    // MARK: BRB

    func startAway() {
        guard !away.isAway else { return }
        away.start(settings: settings)
        applyKeepAwakeMode()
    }

    private func checkIdle() {
        if AwayPolicy.shouldAutoStart(idleSeconds: IdleMonitor.secondsSinceLastInput(), keepAwakeOn: isKeepingAwake,
                                      isAway: away.isAway, settings: settings) {
            startAway()
        }
    }

    // MARK: Launch at login

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchesAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }
}
