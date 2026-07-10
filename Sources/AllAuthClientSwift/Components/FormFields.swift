import Foundation
import SwiftUI
import SwiftyJSON

/// Email input field with validation display
public struct EmailField: View {
    let label: String
    @Binding var text: String
    let errors: JSON?

    init(_ label: String = "Email", text: Binding<String>, errors: JSON? = nil) {
        self.label = label
        self._text = text
        self.errors = errors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            FormErrors(errors: errors, field: "email")
        }
    }
}

/// Username input field with validation display
public struct UsernameField: View {
    let label: String
    @Binding var text: String
    let errors: JSON?

    init(_ label: String = "Username", text: Binding<String>, errors: JSON? = nil) {
        self.label = label
        self._text = text
        self.errors = errors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(.username)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            FormErrors(errors: errors, field: "username")
        }
    }
}

/// Password input field with validation display
public struct PasswordField: View {
    let label: String
    @Binding var text: String
    let errors: JSON?
    let fieldName: String

    init(_ label: String = "Password", text: Binding<String>, errors: JSON? = nil, fieldName: String = "password") {
        self.label = label
        self._text = text
        self.errors = errors
        self.fieldName = fieldName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            SecureField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)

            FormErrors(errors: errors, field: fieldName)
        }
    }
}

/// Generic text input field
public struct InputField: View {
    let label: String
    @Binding var text: String
    let errors: JSON?
    let fieldName: String
    var keyboardType: UIKeyboardType = .default

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)

            FormErrors(errors: errors, field: fieldName)
        }
    }
}

/// Code input field (for OTP, verification codes, etc.)
public struct CodeField: View {
    /// The character set a code uses, which determines the keyboard shown.
    enum Format {
        /// Letter-based codes such as allauth's `XXXX-XXXX` login,
        /// email-verification, and password-reset codes.
        case alphanumeric
        /// Digit-only codes such as 6-digit TOTP codes.
        case numeric
    }

    let label: String
    @Binding var text: String
    let errors: JSON?
    let fieldName: String
    let format: Format

    init(
        _ label: String = "Code",
        text: Binding<String>,
        errors: JSON? = nil,
        fieldName: String = "code",
        format: Format = .alphanumeric
    ) {
        self.label = label
        self._text = text
        self.errors = errors
        self.fieldName = fieldName
        self.format = format
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(format == .numeric ? .numberPad : .asciiCapable)
                .textInputAutocapitalization(format == .numeric ? .never : .characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .font(.system(.title2, design: .monospaced))
                .multilineTextAlignment(.center)

            FormErrors(errors: errors, field: fieldName)
        }
    }
}

extension String {
    /// Normalizes a user-entered verification code before submission:
    /// strips whitespace and the display dashes (codes are shown as
    /// `XXXX-XXXX`) and uppercases to match the server's code alphabet.
    var normalizedCode: String {
        return replacingOccurrences(of: "-", with: "")
            .filter { !$0.isWhitespace }
            .uppercased()
    }
}

// MARK: - Form Container

/// Standard form container with consistent styling
struct AuthForm<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: () -> Content

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                content()
            }
            .padding()
        }
    }
}

/// Form section with title
struct FormSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
            }
            content()
        }
    }
}
