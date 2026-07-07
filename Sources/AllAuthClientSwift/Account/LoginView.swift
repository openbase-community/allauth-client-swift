import Foundation
import LocalAuthentication
import SwiftUI
import SwiftyJSON

/// Login view
/// Equivalent to Login.js in the React implementation
public struct LoginView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var hasSavedPassword = false
    @State private var isFillingPassword = false
    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared
    private let onShake: (() -> Void)?
    private let onSocialProviderSelected: SocialProviderSelectionHandler?
    private let onBack: (() -> Void)?
    private let credentialStore = LoginCredentialStore()

    public init(
        onShake: (() -> Void)? = nil,
        onSocialProviderSelected: SocialProviderSelectionHandler? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.onShake = onShake
        self.onSocialProviderSelected = onSocialProviderSelected
        self.onBack = onBack
    }

    public var body: some View {
        AuthForm(title: "Sign In", subtitle: "Welcome back! Please sign in to continue.") {
            VStack(spacing: 16) {
                // Email or Username field based on config
                if authContext.emailAuthEnabled {
                    EmailField(text: $email, errors: response)
                }

                if authContext.usernameAuthEnabled {
                    UsernameField(text: $username, errors: response)
                }

                HStack(spacing: 8) {
                    PasswordField(text: $password, errors: response)

                    if hasSavedPassword {
                        Button {
                            fillSavedPassword()
                        } label: {
                            if isFillingPassword {
                                ProgressView()
                            } else {
                                Image(systemName: "key.fill")
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isFillingPassword)
                        .accessibilityLabel("Fill saved password")
                    }
                }

                // General errors
                FormErrors(errors: response)

                // Login button
                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    await login()
                }

                if !availableSocialProviders.isEmpty {
                    socialDivider

                    ProviderListView(
                        process: .login,
                        onProviderSelected: onSocialProviderSelected,
                        onSuccess: { result in
                            response = result
                        },
                        onError: { error in
                            response = JSON(["errors": [["message": error.localizedDescription]]])
                        }
                    )
                }

                // Links
                VStack(spacing: 12) {
                    if authContext.loginByCodeEnabled {
                        LinkButton(title: "Sign in with a code instead") {
                            navigationManager.navigate(to: .requestLoginCode)
                        }
                    }

                    LinkButton(title: "Forgot password?") {
                        navigationManager.navigate(to: .requestPasswordReset)
                    }

                    if authContext.signupAllowed {
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            LinkButton(title: "Sign up") {
                                navigationManager.navigate(to: .signup)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onBack()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .onAppear {
            loadSavedCredentials()
        }
        .onShake {
            onShake?()
        }
    }

    private var socialDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 1)

            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 1)
        }
    }

    private var availableSocialProviders: [JSON] {
        authContext.socialProviders.filter { provider in
            onSocialProviderSelected != nil ||
                ProviderListView.builtInProviderIds.contains(provider["id"].stringValue)
        }
    }

    private func login() async {
        response = await performRequest(loading: $isLoading, context: "login") {
            if authContext.emailAuthEnabled && !email.isEmpty {
                return try await client.login(email: email, password: password)
            } else {
                return try await client.login(username: username, password: password)
            }
        }

        if response?.isSuccess == true {
            saveSuccessfulCredentials()
            // Navigation handled by auth context observer
        }
    }

    private func loadSavedCredentials() {
        guard email.isEmpty, username.isEmpty, password.isEmpty else {
            return
        }

        let savedCredentials = credentialStore.loadIdentifier()
        switch savedCredentials.identifierKind {
        case .email:
            email = authContext.emailAuthEnabled ? savedCredentials.identifier : ""
        case .username:
            username = authContext.usernameAuthEnabled ? savedCredentials.identifier : ""
        case nil:
            if authContext.emailAuthEnabled {
                email = savedCredentials.identifier
            } else if authContext.usernameAuthEnabled {
                username = savedCredentials.identifier
            }
        }

        // The saved password sits behind a user-presence Keychain prompt;
        // never read it automatically. Offer the fill button instead.
        hasSavedPassword = credentialStore.hasSavedPassword
    }

    private func fillSavedPassword() {
        isFillingPassword = true
        Task {
            let savedPassword = await credentialStore.loadPassword()
            await MainActor.run {
                if !savedPassword.isEmpty {
                    password = savedPassword
                }
                isFillingPassword = false
            }
        }
    }

    private func saveSuccessfulCredentials() {
        if authContext.emailAuthEnabled && !email.isEmpty {
            credentialStore.save(identifier: email, identifierKind: .email, password: password)
        } else if authContext.usernameAuthEnabled && !username.isEmpty {
            credentialStore.save(identifier: username, identifierKind: .username, password: password)
        }
    }
}

private enum LoginIdentifierKind: String {
    case email
    case username
}

private struct LoginCredentialStore {
    private let identifierKey = "openbase.last_login.identifier"
    private let identifierKindKey = "openbase.last_login.identifier_kind"
    private let legacyPasswordKey = "openbase.last_login.password"
    private let protectedPasswordKey = "openbase.last_login.password.user_presence"
    private let fillPrompt = "Authenticate to fill your saved Openbase password."
    private let migrationPrompt = "Authenticate to protect your saved Openbase password."

    func loadIdentifier() -> (identifier: String, identifierKind: LoginIdentifierKind?) {
        let identifier = UserDefaults.standard.string(forKey: identifierKey) ?? ""
        let identifierKind = UserDefaults.standard.string(forKey: identifierKindKey).flatMap(LoginIdentifierKind.init(rawValue:))
        return (identifier, identifierKind)
    }

    /// Attribute-only Keychain check: does not trigger the presence prompt.
    var hasSavedPassword: Bool {
        KeychainHelper.exists(key: protectedPasswordKey)
            || KeychainHelper.exists(key: legacyPasswordKey)
    }

    func loadPassword() async -> String {
        if let password = KeychainHelper.readUserPresenceProtected(key: protectedPasswordKey, prompt: fillPrompt) {
            return password
        }

        guard KeychainHelper.exists(key: legacyPasswordKey) else {
            return ""
        }

        guard await LocalUserPresenceAuthenticator.authenticate(reason: migrationPrompt),
              let legacyPassword = KeychainHelper.read(key: legacyPasswordKey)
        else {
            return ""
        }

        try? KeychainHelper.saveUserPresenceProtected(key: protectedPasswordKey, value: legacyPassword)
        KeychainHelper.delete(key: legacyPasswordKey)
        return legacyPassword
    }

    func save(identifier: String, identifierKind: LoginIdentifierKind, password: String) {
        UserDefaults.standard.set(identifier, forKey: identifierKey)
        UserDefaults.standard.set(identifierKind.rawValue, forKey: identifierKindKey)
        try? KeychainHelper.saveUserPresenceProtected(key: protectedPasswordKey, value: password)
        KeychainHelper.delete(key: legacyPasswordKey)
    }
}

private enum LocalUserPresenceAuthenticator {
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

// MARK: - Shake Gesture Detection

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

struct ShakeDetector: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

public extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetector(action: action))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
