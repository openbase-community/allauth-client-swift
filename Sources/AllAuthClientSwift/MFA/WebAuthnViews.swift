import Foundation
import SwiftUI
import SwiftyJSON

// MARK: - Add WebAuthn

/// Add WebAuthn authenticator (security key) view
/// Equivalent to AddWebAuthn.js in the React implementation
public struct AddWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var isLoading = false
    @State private var isRegistering = false
    @State private var response: JSON?
    @State private var creationOptions: JSON?
    @State private var showSuccess = false

    private let client = AllAuthClient.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if showSuccess {
                    successView
                } else {
                    setupView
                }
            }
            .padding()
        }
        .navigationTitle("Add Security Key")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCreationOptions()
        }
    }

    var setupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Add Security Key")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use a hardware security key or passkey for an additional layer of security.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("My Security Key", text: $name)
                    .textFieldStyle(.roundedBorder)

                FormErrors(errors: response, field: "name")
            }

            FormErrors(errors: response)

            if creationOptions != nil {
                PrimaryButton(title: "Register Security Key", isLoading: isRegistering) {
                    await registerKey()
                }
            } else if isLoading {
                ProgressView("Loading...")
            } else {
                PrimaryButton(title: "Try Again", isLoading: false) {
                    Task { await loadCreationOptions() }
                }
            }

            SecondaryButton(title: "Cancel", isLoading: false) {
                dismiss()
            }
        }
    }

    var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Security Key Added!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your security key has been registered successfully.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Done", isLoading: false) {
                dismiss()
            }
        }
    }

    private func loadCreationOptions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            creationOptions = try await client.getPasswordlessWebAuthnOptions()
        } catch {
            print("Failed to load creation options: \(error)")
        }
    }

    private func registerKey() async {
        guard name.isEmpty == false else {
            response = JSON(["errors": [["param": "name", "message": "Please enter a name for your security key"]]])
            return
        }

        isRegistering = true
        defer { isRegistering = false }

        // Note: In production, you would use the AuthenticationServices framework
        // to perform actual WebAuthn registration using creationOptions
        // This is a placeholder that shows the flow

        do {
            // Placeholder credential - in production, get from ASAuthorizationController
            let placeholderCredential: [String: Any] = [
                "id": "placeholder",
                "type": "public-key"
            ]

            response = try await client.addWebAuthnAuthenticator(
                name: name,
                credential: placeholderCredential
            )

            if response?.isSuccess == true {
                showSuccess = true
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - List WebAuthn

/// List WebAuthn authenticators view
/// Equivalent to ListWebAuthn.js in the React implementation
public struct ListWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var authenticators: [JSON] = []
    @State private var isLoading = false
    @State private var selectedIds: Set<String> = []

    private let client = AllAuthClient.shared

    public var body: some View {
        List {
            ForEach(Array(authenticators.enumerated()), id: \.offset) { _, auth in
                NavigationLink {
                    UpdateWebAuthnView(authenticator: auth)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth["name"].stringValue)
                                .fontWeight(.medium)

                            Text("Added \(formatDate(auth["created_at"].doubleValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if auth["last_used_at"].double != nil {
                                Text("Last used \(formatDate(auth["last_used_at"].doubleValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if auth["is_passwordless"].boolValue {
                            Label("Passkey", systemImage: "key.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .onDelete(perform: deleteAuthenticators)
        }
        .navigationTitle("Security Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink {
                AddWebAuthnView()
            } label: {
                Image(systemName: "plus")
            }
        }
        .refreshable {
            await loadAuthenticators()
        }
        .task {
            await loadAuthenticators()
        }
    }

    private func loadAuthenticators() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.getWebAuthnAuthenticators()
            if result.isSuccess {
                authenticators = result["data"].arrayValue
            }
        } catch {
            print("Failed to load authenticators: \(error)")
        }
    }

    private func deleteAuthenticators(at offsets: IndexSet) {
        let ids = offsets.map { authenticators[$0]["id"].stringValue }
        Task {
            do {
                _ = try await client.deleteWebAuthnAuthenticators(ids: ids)
                await loadAuthenticators()
            } catch {
                print("Failed to delete authenticators: \(error)")
            }
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "Unknown" }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Update WebAuthn

/// Update WebAuthn authenticator view
/// Equivalent to UpdateWebAuthn.js in the React implementation
public struct UpdateWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext
    @Environment(\.dismiss) var dismiss

    let authenticator: JSON

    @State private var name: String = ""
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var response: JSON?
    @State private var showDeleteConfirmation = false

    private let client = AllAuthClient.shared

    public var body: some View {
        List {
            Section("Name") {
                TextField("Security Key Name", text: $name)
                    .onAppear {
                        name = authenticator["name"].stringValue
                    }

                FormErrors(errors: response, field: "name")
            }

            Section {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(authenticator["is_passwordless"].boolValue ? "Passkey" : "Security Key")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Added")
                    Spacer()
                    Text(formatDate(authenticator["created_at"].doubleValue))
                        .foregroundColor(.secondary)
                }

                if authenticator["last_used_at"].double != nil {
                    HStack {
                        Text("Last Used")
                        Spacer()
                        Text(formatDate(authenticator["last_used_at"].doubleValue))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Remove Security Key")
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Security Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await updateName() }
                }
                .disabled(isLoading || name == authenticator["name"].stringValue)
            }
        }
        .confirmationDialog("Remove Security Key?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                Task { await deleteAuthenticator() }
            }
        } message: {
            Text("This security key will be removed from your account.")
        }
    }

    private func updateName() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await client.updateWebAuthnAuthenticator(
                id: authenticator["id"].stringValue,
                name: name
            )

            if response?.isSuccess == true {
                dismiss()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }

    private func deleteAuthenticator() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            let result = try await client.deleteWebAuthnAuthenticators(
                ids: [authenticator["id"].stringValue]
            )

            if result.isSuccess {
                dismiss()
            }
        } catch {
            print("Failed to delete: \(error)")
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "Unknown" }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Authenticate WebAuthn

/// WebAuthn authentication view
/// Equivalent to AuthenticateWebAuthn.js in the React implementation
public struct AuthenticateWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Security Key",
            subtitle: "Use your security key to sign in."
        ) {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)

                Text("Insert your security key and tap the button, or use your passkey.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                FormErrors(errors: response)

                PrimaryButton(title: "Use Security Key", isLoading: isLoading) {
                    await authenticate()
                }

                // Alternative methods
                if authContext.availableMFATypes.contains(AuthenticatorType.totp.rawValue) {
                    LinkButton(title: "Use authenticator app instead") {
                        navigationManager.pop()
                    }
                }
            }
        }
        .navigationTitle("Security Key")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authenticate() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // First get options
            let options = try await client.getWebAuthnAuthenticateOptions()

            // Note: In production, use AuthenticationServices framework
            // to perform actual WebAuthn authentication
            // This is a placeholder

            let placeholderCredential: [String: Any] = [
                "id": "placeholder",
                "type": "public-key"
            ]

            response = try await client.authenticateWebAuthn(credential: placeholderCredential)

            if response?.isSuccess == true {
                await authContext.refreshAuth()
            }
        } catch {
            response = JSON(["errors": [["message": error.localizedDescription]]])
        }
    }
}

// MARK: - Reauthenticate WebAuthn

/// WebAuthn reauthentication view
/// Equivalent to ReauthenticateWebAuthn.js in the React implementation
public struct ReauthenticateWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    @State private var isLoading = false
    @State private var response: JSON?

    private let client = AllAuthClient.shared

    public var body: some View {
        AuthForm(
            title: "Verify Identity",
            subtitle: "Use your security key to verify your identity."
        ) {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)

                Text("Insert your security key and tap the button.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                FormErrors(errors: response)

                PrimaryButton(title: "Use Security Key", isLoading: isLoading) {
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
            let options = try await client.getWebAuthnReauthenticateOptions()

            // Note: In production, use AuthenticationServices framework
            let placeholderCredential: [String: Any] = [
                "id": "placeholder",
                "type": "public-key"
            ]

            response = try await client.reauthenticateWebAuthn(credential: placeholderCredential)

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

#Preview("Add") {
    NavigationStack {
        AddWebAuthnView()
            .environmentObject(AuthContext.shared)
    }
}

#Preview("Authenticate") {
    NavigationStack {
        AuthenticateWebAuthnView()
            .environmentObject(AuthContext.shared)
            .environmentObject(AuthNavigationManager(authContext: AuthContext.shared))
    }
}
