import AppKit
import BRBuddyCore
import KeyboardShortcuts
import Observation

/// The paw in the menu bar and its menu. BRBuddy owns this `NSStatusItem` itself (rather than SwiftUI's
/// `MenuBarExtra`) so it always knows where the paw is on screen: the first-launch tour hangs the companion from it.
/// The menu is rebuilt each time it opens, so it always shows the current state. Created by `AppDelegate`.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let state: AppState
    private let updates: UpdateController
    private let windows: AppWindows
    private let showTour: () -> Void
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(state: AppState, updates: UpdateController, windows: AppWindows, showTour: @escaping () -> Void) {
        self.state = state
        self.updates = updates
        self.windows = windows
        self.showTour = showTour
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.setAccessibilityLabel("BRBuddy")
        trackIcon()
    }

    /// Where the paw is and the visible frame of its screen. The paw is nil when it isn't on screen: hidden behind the
    /// notch, pushed off by a menu bar organiser, or the menu bar is hidden (BRB is up or a full-screen app is in front).
    func place() -> (anchor: CGRect?, visible: CGRect) {
        let window = item.button?.window
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 875)
        guard item.isVisible, let frame = window?.frame, let screen,
              FirstLaunchTour.isVisible(item: frame, screen: screen.frame, notchLeft: screen.auxiliaryTopLeftArea,
                                        notchRight: screen.auxiliaryTopRightArea) else { return (nil, visible) }
        return (frame, visible)
    }

    #if DEBUG
    /// The menu as it would open now, one line per item (`BRBUDDY_MENU_DUMP=1`).
    func debugMenuLines() -> [String] {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        return menu.items.map { item in
            if item.isSeparatorItem { return "---" }
            let key = item.keyEquivalent.isEmpty ? "" : "  [\(item.keyEquivalentModifierMask.contains(.command) ? "⌘" : "")\(item.keyEquivalent)]"
            return "\(item.state == .on ? "✓ " : "")\(item.title)\(item.isEnabled ? "" : "  (text)")\(key)"
        }
    }
    #endif

    // MARK: Icon

    /// The paw fills in while the Mac is kept awake. Re-arms itself after each change.
    private func trackIcon() {
        let filled = withObservationTracking { state.isKeepingAwake } onChange: { [weak self] in
            Task { @MainActor in self?.trackIcon() }
        }
        let image = NSImage(systemSymbolName: filled ? "pawprint.fill" : "pawprint", accessibilityDescription: "BRBuddy")
        image?.isTemplate = true
        item.button?.image = image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        add(to: menu, "Keep Mac awake", checked: state.manualKeepAwake) { [state] in
            state.setKeepingAwake(!state.manualKeepAwake)
        }
        if state.isKeepingAwakeForAgent && !state.manualKeepAwake {
            note(to: menu, "Kept awake while your agent works")
        }
        let brb = add(to: menu, "BRB now") { [state] in state.startAway() }
        brb.setShortcut(for: .brbNow)
        if state.isKeepingAwake && state.settings.autoStartEnabled {
            note(to: menu, "BRB starts after \(state.settings.idleMinutes) min away")
        }
        if state.proximity.settings.isActive {
            note(to: menu, "Walk-away: \(state.proximity.statusText)")
        }

        menu.addItem(.separator())
        addAgents(to: menu)
        menu.addItem(.separator())

        add(to: menu, "Settings…", key: ",") { [windows] in windows.showSettings() }
        add(to: menu, "Show tour again") { [showTour] in showTour() }
        if updates.isAvailable {
            add(to: menu, "Check for Updates…") { [updates] in updates.checkForUpdates() }
        }
        menu.addItem(.separator())
        note(to: menu, "BRBuddy \(AppVersion.label())")
        add(to: menu, "Quit BRBuddy", key: "q") { NSApplication.shared.terminate(nil) }
    }

    private func addAgents(to menu: NSMenu) {
        let sessions = state.agents.tracker.orderedSessions
        guard !sessions.isEmpty else {
            if state.agents.hooksInstalled.isEmpty {
                note(to: menu, "No agents set up yet")
                add(to: menu, "Set up agents…") { [windows] in windows.showSettings(.agents) }
            } else {
                note(to: menu, "No agents active")
            }
            return
        }
        note(to: menu, "Agents")
        for session in sessions.prefix(6) {
            let project = session.projectName.map { " · \($0)" } ?? ""
            let title = "\(icon(session.activity)) \(session.agent.displayName)\(project) — \(label(session.activity))"
            if TerminalFocuser.hostApp(of: session) != nil {
                // Clicking jumps to the window (and tab, in Terminal and iTerm2) the agent runs in.
                add(to: menu, title) { TerminalFocuser.focus(session) }
            } else {
                note(to: menu, title)
            }
        }
    }

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, key: String = "", checked: Bool = false,
                     action: @escaping @MainActor () -> Void) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: #selector(run(_:)), keyEquivalent: key)
        menuItem.target = self
        menuItem.representedObject = MenuAction(action)
        menuItem.state = checked ? .on : .off
        menu.addItem(menuItem)
        return menuItem
    }

    /// A line of status text: shown, not clickable.
    private func note(to menu: NSMenu, _ title: String) {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        menu.addItem(menuItem)
    }

    @objc private func run(_ sender: NSMenuItem) {
        (sender.representedObject as? MenuAction)?.action()
    }

    private func icon(_ activity: AgentActivity) -> String {
        switch activity {
        case .working: "⚙︎"
        case .waiting: "✋"
        case .finished: "✓"
        case .started, .ended: "·"
        }
    }

    private func label(_ activity: AgentActivity) -> String {
        switch activity {
        case .working: "working"
        case .waiting: "needs you"
        case .finished: "done"
        case .started: "ready"
        case .ended: "closed"
        }
    }
}

/// A menu item's action, carried in its `representedObject`.
private final class MenuAction: NSObject {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
}
