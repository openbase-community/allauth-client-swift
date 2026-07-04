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
        StatusView(
            icon: "checkmark.circle.fill",
            color: .green,
            title: "Security Key Added!",
            message: "Your security key has been registered successfully.",
            buttonTitle: "Done"
        ) {
            dismiss()
        }
    }

    private func loadCreationOptions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            creationOptions = try await client.getPasswordlessWebAuthnOptions()
        } catch {
            AuthDiagnostics.log(
                "AddWebAuthnView",
                "failed to load creation options",
                metadata: ["error": "\(error)"]
            )
        }
    }

    private func registerKey() async {
        guard name.isEmpty == false else {
            response = JSON(["errors": [["param": "name", "message": "Please enter a name for your security key"]]])
            return
        }

        guard let creationOptions else { return }

        response = await performRequest(loading: $isRegistering, context: "register security key") {
            let credential = try await WebAuthnAuthenticator().register(creationOptions: creationOptions)
            return try await client.addWebAuthnAuthenticator(
                name: name,
                credential: credential
            )
        }

        if response?.isSuccess == true {
            showSuccess = true
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

                            Text("Added \(AuthDateFormatting.relativeDate(fromTimestamp: auth["created_at"].doubleValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if auth["last_used_at"].double != nil {
                                Text("Last used \(AuthDateFormatting.relativeDate(fromTimestamp: auth["last_used_at"].doubleValue))")
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
        let result = await performRequest(loading: $isLoading, context: "load authenticators") {
            try await client.getWebAuthnAuthenticators()
        }
        if result.isSuccess {
            authenticators = result["data"].arrayValue
        }
    }

    private func deleteAuthenticators(at offsets: IndexSet) {
        let ids = offsets.map { authenticators[$0]["id"].stringValue }
        Task {
            do {
                _ = try await client.deleteWebAuthnAuthenticators(ids: ids)
                await loadAuthenticators()
            } catch {
                AuthDiagnostics.log(
                    "ListWebAuthnView",
                    "failed to delete authenticators",
                    metadata: ["error": "\(error)"]
                )
            }
        }
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
                    Text(AuthDateFormatting.absoluteDate(fromTimestamp: authenticator["created_at"].doubleValue))
                        .foregroundColor(.secondary)
                }

                if authenticator["last_used_at"].double != nil {
                    HStack {
                        Text("Last Used")
                        Spacer()
                        Text(AuthDateFormatting.absoluteDate(fromTimestamp: authenticator["last_used_at"].doubleValue))
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
        response = await performRequest(loading: $isLoading, context: "update security key") {
            try await client.updateWebAuthnAuthenticator(
                id: authenticator["id"].stringValue,
                name: name
            )
        }

        if response?.isSuccess == true {
            dismiss()
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
            AuthDiagnostics.log(
                "UpdateWebAuthnView",
                "failed to delete authenticator",
                metadata: ["error": "\(error)"]
            )
        }
    }
}

// MARK: - WebAuthn Prompt Form

/// Shared form for the WebAuthn authenticate/reauthenticate flows
struct WebAuthnPromptForm<Footer: View>: View {
    let title: String
    let subtitle: String
    let message: String
    let submit: @MainActor () async throws -> JSON
    let onSuccess: @MainActor () async -> Void
    @ViewBuilder let footer: () -> Footer

    @State private var isLoading = false
    @State private var response: JSON?

    var body: some View {
        AuthForm(
            title: title,
            subtitle: subtitle
        ) {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)

                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                FormErrors(errors: response)

                PrimaryButton(title: "Use Security Key", isLoading: isLoading) {
                    await run()
                }

                footer()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run() async {
        response = await performRequest(loading: $isLoading, context: "WebAuthn authentication") {
            try await submit()
        }

        if response?.isSuccess == true {
            await onSuccess()
        }
    }
}

// MARK: - Authenticate WebAuthn

/// WebAuthn authentication view
/// Equivalent to AuthenticateWebAuthn.js in the React implementation
public struct AuthenticateWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    private let client = AllAuthClient.shared

    public var body: some View {
        WebAuthnPromptForm(
            title: "Security Key",
            subtitle: "Use your security key to sign in.",
            message: "Insert your security key and tap the button, or use your passkey.",
            submit: {
                let options = try await client.getWebAuthnAuthenticateOptions()
                let credential = try await WebAuthnAuthenticator().authenticate(requestOptions: options)
                return try await client.authenticateWebAuthn(credential: credential)
            },
            onSuccess: {
                await authContext.refreshAuth()
            }
        ) {
            // Alternative methods
            if authContext.availableMFATypes.contains(AuthenticatorType.totp.rawValue) {
                LinkButton(title: "Use authenticator app instead") {
                    navigationManager.pop()
                }
            }
        }
    }
}

// MARK: - Reauthenticate WebAuthn

/// WebAuthn reauthentication view
/// Equivalent to ReauthenticateWebAuthn.js in the React implementation
public struct ReauthenticateWebAuthnView: View {
    @EnvironmentObject var authContext: AuthContext
    @EnvironmentObject var navigationManager: AuthNavigationManager

    private let client = AllAuthClient.shared

    public var body: some View {
        WebAuthnPromptForm(
            title: "Verify Identity",
            subtitle: "Use your security key to verify your identity.",
            message: "Insert your security key and tap the button.",
            submit: {
                let options = try await client.getWebAuthnReauthenticateOptions()
                let credential = try await WebAuthnAuthenticator().authenticate(requestOptions: options)
                return try await client.reauthenticateWebAuthn(credential: credential)
            },
            onSuccess: {
                await authContext.refreshAuth()
                navigationManager.pop()
            }
        ) {
            LinkButton(title: "Cancel") {
                navigationManager.pop()
            }
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
