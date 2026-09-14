import SwiftUI

private struct PasswordAutofillEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {
    /// Controls saved-login storage and password AutoFill throughout the auth UI.
    /// Disable for disposable test accounts; entered passwords remain masked.
    var authPasswordAutofillEnabled: Bool {
        get { self[PasswordAutofillEnabledKey.self] }
        set { self[PasswordAutofillEnabledKey.self] = newValue }
    }
}

extension View {
    /// An explicit non-password type avoids password heuristics on SecureField;
    /// nil alone leaves iOS free to infer a saved-password login form.
    func authCredentialContentType(_ type: UITextContentType, autofillEnabled: Bool) -> some View {
        textContentType(autofillEnabled ? type : .oneTimeCode)
    }
}
