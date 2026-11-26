import AppKit
import SwiftUI

/// Opens BRBuddy's own windows: Settings (a toolbar tab per `SettingsTab`) and Companion Studio. Created by
/// `AppDelegate`; used by the menu bar item, the tour and the Companion tab. AppKit owns these windows (not SwiftUI
/// scenes) so any part of the app can open them, including the AppKit menu, and open Settings at a given tab.
@MainActor
final class AppWindows {
    private let state: AppState
    private var settingsWindow: NSWindow?
    private var settingsTabs: NSTabViewController?
    private var studioWindow: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    /// Shows Settings in front, at `tab` if given (otherwise where it was left).
    func showSettings(_ tab: SettingsTab? = nil) {
        let window = settingsWindow ?? makeSettings()
        if let tab { settingsTabs?.selectedTabViewItemIndex = tab.rawValue }
        bringForward(window)
    }

    func showStudio() {
        let window = studioWindow ?? makeStudio()
        bringForward(window)
    }

    /// BRBuddy has no Dock icon, so without activating it a window opens behind other apps'.
    private func bringForward(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeSettings() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let view = SettingsView(state: state, tab: tab) { [weak self] in self?.showStudio() }
            let controller = NSHostingController(rootView: view)
            controller.title = tab.title  // the window's title follows the selected tab
            controller.sizingOptions = []
            controller.preferredContentSize = SettingsView.size
            let item = NSTabViewItem(viewController: controller)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        settingsTabs = tabs
        settingsWindow = window
        return window
    }

    private func makeStudio() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: CompanionStudioView(library: state.companions)))
        window.title = "Companion Studio"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        studioWindow = window
        return window
    }
}
