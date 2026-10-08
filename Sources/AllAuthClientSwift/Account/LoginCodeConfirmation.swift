import Foundation
import SwiftUI
import SwiftyJSON

/// Submits a login code and decides what the Enter Code screen does next.
///
/// Every outcome either leaves the screen (signed in, or the server moved on
/// to another step) or carries an error the screen renders. A submission is
/// never a silent no-op. Kept apart from the view so it can be unit tested.
@MainActor
struct LoginCodeConfirmation {
    enum Outcome: Equatable {
        /// The code was accepted and the user is signed in.
        case signedIn
        /// The code was accepted and the server wants another step (for
        /// example MFA). The auth root renders that pending flow.
        case nextStep
        /// Stay on the screen and show the errors in the result's response.
        case showErrors
        /// The login-code flow is gone on the server: the code expired, too
        /// many wrong attempts were made, or no code was requested in this
        /// session. The user has to request a new code.
        case restartFlow
    }

    struct Result {
        /// The response to render. For `showErrors` and `restartFlow` it
        /// always holds at least one error the screen displays.
        let response: JSON
        let outcome: Outcome
    }

    static let emptyCodeMessage = "Enter the code from your email."
    static let expiredMessage = "That sign-in code has expired or is no longer valid. Request a new code to continue."
    static let unexpectedMessage = "Sign-in didn't complete. Please try again."

    let confirm: @MainActor (String) async throws -> JSON

    init(confirm: @escaping @MainActor (String) async throws -> JSON) {
        self.confirm = confirm
    }

    func submit(code rawCode: String, loading isLoading: Binding<Bool>? = nil) async -> Result {
        let code = rawCode.normalizedCode
        guard !code.isEmpty else {
            return Result(
                response: Self.errorResponse(Self.emptyCodeMessage, param: "code"),
                outcome: .showErrors
            )
        }

        let response = await performRequest(loading: isLoading, context: "confirm login code") {
            try await confirm(code)
        }
        return Self.interpret(response)
    }

    static func interpret(_ response: JSON) -> Result {
        switch response["status"].int {
        case 200:
            return Result(response: response, outcome: .signedIn)
        case 409:
            // allauth answers 409 with no error message when the pending
            // login-code stage is gone (it expires after a few minutes).
            AuthDiagnostics.log("AuthView", "login code flow no longer pending; restarting")
            return Result(response: errorResponse(expiredMessage), outcome: .restartFlow)
        case 401 where hasOtherPendingFlow(response):
            return Result(response: response, outcome: .nextStep)
        default:
            return Result(response: withDisplayableError(response), outcome: .showErrors)
        }
    }

    /// The Enter Code screen shows general errors and errors for `code`.
    /// Make sure the response carries at least one of those.
    static func withDisplayableError(_ response: JSON) -> JSON {
        let errors = response["errors"].arrayValue
        let displayable = errors.contains { error in
            let param = error["param"].string
            return (param == nil || param == "code") && error["message"].string?.isEmpty == false
        }
        if displayable {
            return response
        }

        var patched = response
        let message = errors.compactMap { $0["message"].string }.first { !$0.isEmpty } ?? unexpectedMessage
        patched["errors"] = JSON(errors.map { $0.object } + [["message": message]])
        return patched
    }

    static func errorResponse(_ message: String, param: String? = nil) -> JSON {
        var error: [String: Any] = ["message": message]
        if let param {
            error["param"] = param
        }
        return JSON(["errors": [error]])
    }

    private static func hasOtherPendingFlow(_ response: JSON) -> Bool {
        response["data"]["flows"].arrayValue.contains { flow in
            flow["is_pending"].boolValue && flow["id"].string != AuthFlow.loginByCode.rawValue
        }
    }
}
