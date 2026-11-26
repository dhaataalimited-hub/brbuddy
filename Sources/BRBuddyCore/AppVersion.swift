import Foundation

/// The version BRBuddy shows in its menu and Settings, read from the app's Info.plist. Release builds carry the
/// version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`); a copy run with `swift run` has
/// neither, so it says it is a development build.
public enum AppVersion {
    /// "0.1.3" or "0.1.3 (12)"; "Development build" when there is no version.
    public static func label(info: [String: Any]? = Bundle.main.infoDictionary) -> String {
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        guard !version.isEmpty else { return "Development build" }
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty || build == version ? version : "\(version) (\(build))"
    }
}
