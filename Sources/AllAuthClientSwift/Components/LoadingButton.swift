import Foundation
import SwiftUI

/// A button that shows a loading state
/// Equivalent to Button component in React implementation
public struct LoadingButton<Label: View>: View {
    let action: () async -> Void
    let isLoading: Bool
    @ViewBuilder let label: () -> Label

    @State private var isExecuting = false

    public var body: some View {
        Button {
            guard !isLoading && !isExecuting else { return }
            Task {
                isExecuting = true
                await action()
                isExecuting = false
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading || isExecuting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                label()
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading || isExecuting)
    }
}

/// Primary styled loading button
public struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void

    public var body: some View {
        LoadingButton(action: action, isLoading: isLoading) {
            Text(title)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

/// Secondary styled loading button
public struct SecondaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void

    public var body: some View {
        LoadingButton(action: action, isLoading: isLoading) {
            Text(title)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

/// Destructive styled loading button
public struct DestructiveButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void

    public var body: some View {
        LoadingButton(action: action, isLoading: isLoading) {
            Text(title)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
    }
}

/// Text-only button (link style)
public struct LinkButton: View {
    let title: String
    let action: () -> Void

    public var body: some View {
        Button(title, action: action)
            .font(.subheadline)
    }
}
