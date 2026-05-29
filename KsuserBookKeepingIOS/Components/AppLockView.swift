import SwiftUI

struct AppLockView: View {
    @ObservedObject var appLock: AppLockManager

    @Environment(\.colorScheme) private var colorScheme
    @State private var password = ""
    @State private var didTryBiometrics = false
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 92, height: 92)
                        .shadow(color: Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.28), radius: 18, y: 8)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.black)
                }

                Text("appLock.title")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("appLock.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)

                    SecureField("appLock.password.placeholder", text: $password)
                        .font(.body)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .onSubmit(unlock)
                        .focused($isPasswordFocused)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isPasswordFocused ? Color.accentColor.opacity(0.75) : Color(.separator).opacity(0.35),
                            lineWidth: isPasswordFocused ? 1.5 : 1
                        )
                }

                Button("appLock.unlock", action: unlock)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(password.isEmpty)

                if appLock.isBiometricUnlockEnabled && appLock.isBiometricAvailable {
                    Button("appLock.useBiometrics") {
                        authenticateWithBiometrics()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .font(.headline)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.accentColor)
                }

                if let messageKey = appLock.messageKey {
                    Text(LocalizedStringKey(messageKey))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: 440)

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isPasswordFocused = true
            guard !didTryBiometrics else { return }

            if appLock.isBiometricUnlockEnabled && appLock.isBiometricAvailable {
                didTryBiometrics = true
                authenticateWithBiometrics()
            }
        }
    }

    private func unlock() {
        appLock.unlock(with: password)

        if !appLock.isLocked {
            password = ""
        }
    }

    private func authenticateWithBiometrics() {
        appLock.unlockWithBiometrics(
            reason: NSLocalizedString("appLock.biometric.reason", comment: "")
        )
    }
}
