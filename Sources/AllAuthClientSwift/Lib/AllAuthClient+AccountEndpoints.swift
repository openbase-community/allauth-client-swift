import Foundation
import SwiftyJSON

@MainActor
extension AllAuthClient {
    // MARK: - Email Address Management

    public func getEmailAddresses() async throws -> JSON {
        return try await request(method: "GET", url: urls.emailAddresses)
    }

    public func addEmailAddress(email: String) async throws -> JSON {
        return try await request(
            method: "POST",
            url: urls.emailAddresses,
            data: ["email": email]
        )
    }

    public func deleteEmailAddress(email: String) async throws -> JSON {
        return try await request(
            method: "DELETE",
            url: urls.emailAddresses,
            data: ["email": email]
        )
    }

    public func setPrimaryEmailAddress(email: String) async throws -> JSON {
        return try await request(
            method: "PATCH",
            url: urls.emailAddresses,
            data: ["email": email, "primary": true]
        )
    }

    public func requestEmailVerification(email: String) async throws -> JSON {
        return try await request(
            method: "PUT",
            url: urls.emailAddresses,
            data: ["email": email]
        )
    }

    // MARK: - Password Change

    public func changePassword(currentPassword: String?, newPassword: String) async throws -> JSON {
        var data: [String: Any] = ["new_password": newPassword]
        if let current = currentPassword {
            data["current_password"] = current
        }
        return try await request(method: "POST", url: urls.changePassword, data: data)
    }
}
