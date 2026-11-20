import Foundation
import OpenDirectory

/// Checks the current macOS user's login password, so BRB can unlock from a password field inside its own window
/// (a system password dialog would open underneath the away screen).
public enum PasswordVerifier {
    /// The current user's directory record, if it can be found.
    public static func currentUserRecord() -> ODRecord? {
        guard let node = try? ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeAuthentication))
        else { return nil }
        return try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil)
    }

    /// Whether `password` is the current user's login password. Slow (macOS throttles it), so call it off the main
    /// thread. Each wrong password counts toward the account's failed-login policy.
    public static func verify(_ password: String) -> Bool {
        guard !password.isEmpty, let record = currentUserRecord() else { return false }
        return (try? record.verifyPassword(password)) != nil
    }
}
