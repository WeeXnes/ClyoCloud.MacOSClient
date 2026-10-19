import SwiftUI

public struct LoginView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settings = SettingsManager.shared

    @State private var loginMode: Int = 0 // 0: Quick Token / QR, 1: Username & Password
    @State private var serverUrlInput: String = ""
    @State private var quickPayloadInput: String = ""
    @State private var usernameInput: String = ""
    @State private var passwordInput: String = ""
    @State private var totpCodeInput: String = ""
    @State private var isAwaiting2FA: Bool = false
    @State private var temp2FAToken: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // App Branding
            HStack(spacing: 10) {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClyoCloud")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("macOS Native Client")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 14)

            // Server URL Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Server Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("http://localhost:6969 or https://cloud.example.com", text: $serverUrlInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
            }
            .padding(.horizontal)

            // Picker Mode
            Picker("", selection: $loginMode) {
                Text("Quick Token / QR").tag(0)
                Text("Credentials").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            if loginMode == 0 {
                // Quick Token / QR Flow
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste Token or QR JSON")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $quickPayloadInput)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 70)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    Text("Tip: In ClyoCloud web settings, click 'Generate Login QR Code' and copy the token or payload.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                // Username & Password Flow
                VStack(spacing: 8) {
                    if !isAwaiting2FA {
                        TextField("Username", text: $usernameInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        SecureField("Password", text: $passwordInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Two-Factor Authentication")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Enter the 6-digit TOTP code from your authenticator app or an emergency recovery code.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            TextField("123456", text: $totpCodeInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Error or Info Message
            if let err = errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            if let info = infoMessage {
                Text(info)
                    .font(.caption2)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Submit Button
            Button(action: handleLogin) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    }
                    Text(isAwaiting2FA ? "Verify 2FA" : "Connect & Login")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.blue)
            .disabled(isSubmitting)
            .padding(.horizontal)
            .padding(.bottom, 14)
        }
        .onAppear {
            self.serverUrlInput = settings.serverUrl
            self.usernameInput = settings.username
        }
    }

    private func handleLogin() {
        errorMessage = nil
        infoMessage = nil
        settings.serverUrl = serverUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)

        isSubmitting = true
        Task {
            if loginMode == 0 {
                let res = await appState.loginWithDevicePayload(quickPayloadInput)
                if res.success {
                    infoMessage = res.message
                } else {
                    errorMessage = res.message
                }
            } else {
                if isAwaiting2FA {
                    let res = await appState.verify2FA(
                        tempToken: temp2FAToken,
                        code: totpCodeInput.trimmingCharacters(in: .whitespacesAndNewlines),
                        username: usernameInput
                    )
                    if res.success {
                        infoMessage = res.message
                    } else {
                        errorMessage = res.message
                    }
                } else {
                    let res = await appState.loginWithCredentials(
                        username: usernameInput.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: passwordInput
                    )
                    if res.requires2fa, let temp = res.tempToken {
                        isAwaiting2FA = true
                        temp2FAToken = temp
                        infoMessage = "Password verified. Enter your 2FA code."
                    } else if res.success {
                        infoMessage = res.message
                    } else {
                        errorMessage = res.message
                    }
                }
            }
            isSubmitting = false
        }
    }
}
