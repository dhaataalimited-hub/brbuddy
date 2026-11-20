import Foundation
import Sparkle

/// Automatic updates through Sparkle. Only runs in builds that carry a feed address and Sparkle public key in their
/// Info.plist (release builds); local and test builds have no updater, so they never check or nag. Owned by
/// `AppDelegate`.
@MainActor
final class UpdateController {
    private let controller: SPUStandardUpdaterController?

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = (info["SUFeedURL"] as? String) ?? ""
        let key = (info["SUPublicEDKey"] as? String) ?? ""
        controller = feed.isEmpty || key.isEmpty ? nil
            : SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
