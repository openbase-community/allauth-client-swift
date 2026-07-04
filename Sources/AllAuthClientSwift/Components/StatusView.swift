import Foundation
import SwiftUI

/// Shared status screen with a large icon, title, optional message, and an
/// optional primary action button
public struct StatusView: View {
    let icon: String
    let color: Color
    let title: String
    let message: String?
    let spacing: CGFloat
    let buttonTitle: String?
    let action: (() async -> Void)?

    public init(
        icon: String,
        color: Color,
        title: String,
        message: String? = nil,
        spacing: CGFloat = 24,
        buttonTitle: String? = nil,
        action: (() async -> Void)? = nil
    ) {
        self.icon = icon
        self.color = color
        self.title = title
        self.message = message
        self.spacing = spacing
        self.buttonTitle = buttonTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(color)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            if let message {
                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let action {
                PrimaryButton(title: buttonTitle, isLoading: false, action: action)
            }
        }
    }
}
