import BRBuddyCore
import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import SwiftUI

/// Touch ID and a password field, drawn inside the away window so no system dialog opens behind it.
struct UnlockPanel: View {
    let controller: AwayController

    @State private var password = ""
    @State private var checking = false
    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            if controller.biometricsAvailable {
                TouchIDView(context: controller.authContext) { controller.evaluateTouchID() }
                    .id(ObjectIdentifier(controller.authContext))
                    .frame(width: 64, height: 64)
                Text("Touch ID or enter your password")
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Enter your password")
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack {
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .focused($passwordFocused)
                    .onSubmit(check)
                    .disabled(checking)
                Button(checking ? "Checking…" : "Unlock", action: check)
                    .disabled(checking || password.isEmpty)
            }

            if let message = controller.lastFailureMessage {
                Text(message)
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 15, design: .rounded))
        .onAppear { passwordFocused = true }
    }

    private func check() {
        guard !checking, !password.isEmpty else { return }
        checking = true
        let attempt = password
        Task.detached(priority: .userInitiated) {
            let ok = PasswordVerifier.verify(attempt)
            await MainActor.run {
                checking = false
                password = ""
                controller.passwordChecked(ok)
            }
        }
    }
}

/// Apple's embeddable Touch ID view, bound to one `LAContext`.
private struct TouchIDView: NSViewRepresentable {
    let context: LAContext
    let onReady: @MainActor () -> Void

    func makeNSView(context _: Context) -> LAAuthenticationView {
        let view = LAAuthenticationView(context: context, controlSize: .regular)
        // Start Touch ID on the next run-loop turn, once the view is in the window.
        Task { @MainActor in onReady() }
        return view
    }

    func updateNSView(_: LAAuthenticationView, context _: Context) {}
}
