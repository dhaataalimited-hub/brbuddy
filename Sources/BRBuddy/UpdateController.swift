import Foundation
import Sparkle

/// Automatic updates through Sparkle. Only runs in builds that carry a feed address and Sparkle public key in their
/// Info.plist (release builds); local and test builds have no updater, so they never check or nag. Owned by
/// `AppDelegate`.
@MainActor
final class UpdateController {
    private let controller: SPUStandardUpdaterController?
    private let logger = UpdateLogger()

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = (info["SUFeedURL"] as? String) ?? ""
        let key = (info["SUPublicEDKey"] as? String) ?? ""
        controller = feed.isEmpty || key.isEmpty ? nil
            : SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: logger, userDriverDelegate: nil)
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

/// Writes what the updater finds to the log.
private final class UpdateLogger: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        AppLog.info(.updates, "Update found: \(item.displayVersionString)")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        AppLog.info(.updates, "Up to date")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        AppLog.info(.updates, "Update check ended: \(error.localizedDescription)")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        AppLog.info(.updates, "Installing \(item.displayVersionString)")
    }
}
