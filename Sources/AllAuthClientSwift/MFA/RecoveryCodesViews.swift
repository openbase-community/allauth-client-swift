import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Generate Recovery Codes

/// Generate new recovery codes view
/// Equivalent to GenerateRecoveryCodes.js in the React implementation
public struct GenerateRecoveryCodesView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var response: JSON?
    @State private var codes: [String] = []
    @State private var showConfirmation = false

    private let client = AllAuthClient.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if codes.isEmpty {
                    generateView
                } else {
                    codesView
                }
            }
            .padding()
        }
        .navigationTitle("Recovery Codes")
        .navigationBarTitleDisplayMode(.inline)
    }

    var generateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Generate Recovery Codes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Recovery codes allow you to access your account if you lose access to your authenticator app. Each code can only be used once.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if showConfirmation {
                VStack(spacing: 16) {
                    Text("This will invalidate any existing recovery codes. Are you sure?")
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        SecondaryButton(title: "Cancel", isLoading: false) {
                            showConfirmation = false
                        }

                        PrimaryButton(title: "Generate", isLoading: isLoading) {
                            await generateCodes()
                        }
                    }
                }
            } else {
                PrimaryButton(title: "Generate Codes", isLoading: isLoading) {
                    showConfirmation = true
                }
            }

            FormErrors(errors: response)
        }
    }

    var codesView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Your Recovery Codes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Save these codes in a safe place. You won't be able to see them again.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Codes display
            VStack(spacing: 8) {
                ForEach(Array(codes.enumerated()), id: \.offset) { index, code in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)

                        Text(code)
                            .font(.system(.body, design: .monospaced))

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // Copy button
            Button {
                let codesText = codes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                UIPasteboard.general.string = codesText
            } label: {
                Label("Copy All Codes", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)

            PrimaryButton(title: "I've Saved These Codes", isLoading: false) {
                dismiss()
            }
        }
    }

    private func generateCodes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.generateRecoveryCodes()

            if response?.isSuccess == true {
                codes = response?["data"]["unused_codes"].arrayValue.map { $0.stringValue } ?? []
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - View Recovery Codes

/// View existing recovery codes
/// Equivalent to RecoveryCodes.js in the React implementation
public struct RecoveryCodesView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var isLoading = false
    @State private var unusedCodes: [String] = []
    @State private var totalCount = 0

    private let client = AllAuthClient.shared

    public var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if unusedCodes.isEmpty {
                    VStack(spacing: 8) {
                        Text("No unused codes remaining")
                            .foregroundColor(.secondary)

                        NavigationLink {
                            GenerateRecoveryCodesView()
                        } label: {
                            Text("Generate new codes")
                        }
                    }
                    .padding(.vertical)
                } else {
                    ForEach(unusedCodes, id: \.self) { code in
                        HStack {
                            Text(code)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                    }
                }
            } header: {
                Text("Unused Codes (\(unusedCodes.count) of \(totalCount))")
            } footer: {
                Text("Each code can only be used once. Generate new codes if you run low.")
            }

            Section {
                NavigationLink {
                    GenerateRecoveryCodesView()
                } label: {
                    Label("Generate New Codes", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        .navigationTitle("Recovery Codes")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadCodes()
        }
        .task {
            await loadCodes()
        }
    }

    private func loadCodes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.getRecoveryCodes()
            if result.isSuccess {
                unusedCodes = result["data"]["unused_codes"].arrayValue.map { $0.stringValue }
                totalCount = result["data"]["total_code_count"].intValue
            }
        } catch {
            print("Failed to load recovery codes: \(error)")
        }
    }
}

// MARK: - Authenticate with Recovery Code

/// Authenticate using recovery code view
/// Equivalent to AuthenticateRecoveryCodes.js in the React implementation
public struct AuthenticateRecoveryCodesView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Recovery Code",
            subtitle: "Enter one of your recovery codes to sign in."
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("xxxx-xxxx", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    FormErrors(errors: response, field: "code")
                }

                FormErrors(errors: response)

                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    await authenticate()
                }

                LinkButton(title: "Use authenticator app instead") {
                    navigationManager.pop()
                }
            }
        }
        .navigationTitle("Recovery Code")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authenticate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.authenticateWithRecoveryCode(code: code)

            if response?.isSuccess == true {
                await authContext.refreshAuth()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Reauthenticate with Recovery Code

/// Reauthenticate using recovery code view
/// Equivalent to ReauthenticateRecoveryCodes.js in the React implementation
public struct ReauthenticateRecoveryCodesView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var code = ""
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Verify Identity",
            subtitle: "Enter one of your recovery codes to verify your identity."
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("xxxx-xxxx", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    FormErrors(errors: response, field: "code")
                }

                FormErrors(errors: response)

                PrimaryButton(title: "Verify", isLoading: isLoading) {
                    await reauthenticate()
                }

                LinkButton(title: "Cancel") {
                    navigationManager.pop()
                }
            }
        }
        .navigationTitle("Verify Identity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reauthenticate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.reauthenticateWithRecoveryCode(code: code)

            if response?.isSuccess == true {
                await authContext.refreshAuth()
                navigationManager.pop()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Preview

#Preview("Generate") {
    NavigationStack {
        GenerateRecoveryCodesView()
            .environmentObject(AuthContext.shared)
    }
}

#Preview("View") {
    NavigationStack {
        RecoveryCodesView()
            .environmentObject(AuthContext.shared)
    }
}

#Preview("Authenticate") {
    NavigationStack {
        AuthenticateRecoveryCodesView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
