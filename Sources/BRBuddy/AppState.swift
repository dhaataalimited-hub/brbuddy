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
/// Owns keep-awake, the agent monitor, the away controller and the idle check. The Mac is kept awake when the user
/// turned it on, or by itself while an agent is working or waiting (if that setting is on). While kept awake with
/// auto-start enabled it also keeps the display on, so macOS's own screen saver or display sleep can't beat BRB.
@MainActor
@Observable
final class AppState {
    private let keepAwake = KeepAwake()
    let away = AwayController()
    let agents = AgentMonitor()
    let companions = CompanionLibrary()

    /// Keep-awake switched on by hand from the menu.
    private(set) var manualKeepAwake = false
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
        away.agents = agents
        away.companions = companions
        away.onEnded = { [weak self] _ in self?.applyKeepAwakeMode() }
        agents.onChange = { [weak self] in self?.applyKeepAwakeMode() }
        KeyboardShortcuts.onKeyUp(for: .brbNow) { [weak self] in self?.startAway() }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
    }

    // MARK: Keep awake

    /// Whether the Mac is being kept awake right now, by hand or for an agent.
    var isKeepingAwake: Bool { manualKeepAwake || isKeepingAwakeForAgent }

    var isKeepingAwakeForAgent: Bool { settings.keepAwakeForAgents && agents.summary.isActive }

    func setKeepingAwake(_ on: Bool) {
        manualKeepAwake = on
        applyKeepAwakeMode()
    }

    private func applyKeepAwakeMode() {
        if away.isAway {
            keepAwake.activate(.systemAndDisplay, reason: "BRBuddy is showing the away screen")
        } else if isKeepingAwake {
            let mode: KeepAwake.Mode = settings.autoStartEnabled ? .systemAndDisplay : .systemOnly
            let reason = isKeepingAwakeForAgent && !manualKeepAwake
                ? "BRBuddy is keeping your Mac awake while an agent works"
                : "BRBuddy is keeping your Mac awake"
            if !keepAwake.activate(mode, reason: reason) { manualKeepAwake = false }
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
