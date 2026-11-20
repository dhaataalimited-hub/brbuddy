import Foundation

/// Locks the Mac with the real macOS lock screen.
///
/// Uses `SACLockScreenImmediate` from the private login framework, the same call Hammerspoon (MIT) uses for
/// `hs.caffeinate.lockScreen`. Private API is fine because BRBuddy ships outside the App Store. If the symbol is ever
/// missing, falls back to sleeping the display, which locks only when "Require password immediately" is set.
public enum ScreenLocker {
    private typealias LockFunction = @convention(c) () -> Int32

    private static let loginFramework = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"

    private static func lockFunction() -> LockFunction? {
        guard let handle = dlopen(loginFramework, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(symbol, to: LockFunction.self)
    }

    /// Whether the real lock call is available on this macOS. Checked by tests without locking anything.
    public static var canLockImmediately: Bool { lockFunction() != nil }

    /// Shows the macOS lock screen now.
    public static func lockNow() {
        if let lock = lockFunction() {
            _ = lock()
            return
        }
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["displaysleepnow"]
        try? pmset.run()
    }
}
