import Foundation
import SwiftUI
import SwiftyJSON

/// Displays form errors from API responses
/// Equivalent to FormErrors.js in the React implementation
public struct FormErrors: View {
    let errors: JSON?
    let field: String?

    init(errors: JSON?, field: String? = nil) {
        self.errors = errors
        self.field = field
    }

    var relevantErrors: [String] {
        guard let errorsArray = errors?["errors"].array else {
            return []
        }

        return errorsArray.compactMap { error -> String? in
            let param = error["param"].string
            let message = error["message"].string

            if let field = field {
                // Return only errors for this specific field
                if param == field {
                    return message
                }
            } else {
                // Return general errors (no param) if no field specified
                if param == nil {
                    return message
                }
            }
            return nil
        }
    }

    public var body: some View {
        ForEach(relevantErrors, id: \.self) { error in
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Displays all errors from a response
public struct AllFormErrors: View {
    let response: JSON?

    var allErrors: [(field: String?, message: String)] {
        guard let errorsArray = response?["errors"].array else {
            return []
        }

        return errorsArray.compactMap { error -> (field: String?, message: String)? in
            guard let message = error["message"].string else { return nil }
            return (error["param"].string, message)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(allErrors.enumerated()), id: \.offset) { _, error in
                HStack(alignment: .top, spacing: 4) {
                    if let field = error.field {
                        Text("\(field):")
                            .fontWeight(.medium)
                    }
                    Text(error.message)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Alert-style error display
public struct ErrorAlert: View {
    let message: String
    var onDismiss: (() -> Void)?

    public var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Success message display
public struct SuccessAlert: View {
    let message: String
    var onDismiss: (() -> Void)?

    public var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

            Text(message)
                .font(.subheadline)

            Spacer()

            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Response Status Helpers

extension JSON {
    /// Check if response has any errors
    var hasErrors: Bool {
        return self["errors"].array?.isEmpty == false
    }

    /// Get first general error message
    var firstGeneralError: String? {
        return self["errors"].array?.first { $0["param"].string == nil }?["message"].string
    }

    /// Get all error messages as array
    var allErrorMessages: [String] {
        return self["errors"].array?.compactMap { $0["message"].string } ?? []
    }
}
