import Foundation
import LocalAuthentication

enum AppLock {
    static let enabledKey = "appLockEnabled"

    /// Returns true if unlocked (Face ID/passcode succeeded), or if the
    /// device has neither biometrics nor a passcode configured — a device
    /// with no passcode offers no real protection, so we never lock a user
    /// out of their own medical records over a device configuration gap.
    /// Returns false only when authentication is available but fails or is
    /// cancelled by the user.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
