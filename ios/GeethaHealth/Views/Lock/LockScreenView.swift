import SwiftUI

struct LockScreenView: View {
    var onUnlock: () -> Void
    @State private var isAuthenticating = false
    @State private var didFail = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Geetha Health Locked")
                .font(.title2.bold())
            if didFail {
                Text("Couldn't verify your identity.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button(isAuthenticating ? "Unlocking…" : "Unlock") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task {
            authenticate()
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        didFail = false
        Task {
            let success = await AppLock.authenticate(reason: "Unlock Geetha Health")
            isAuthenticating = false
            if success {
                onUnlock()
            } else {
                didFail = true
            }
        }
    }
}
