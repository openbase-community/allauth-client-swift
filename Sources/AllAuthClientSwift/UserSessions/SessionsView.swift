import Foundation
import SwiftUI
import SwiftyJSON

/// User sessions management view
/// Equivalent to Sessions.js in the React implementation
public struct SessionsView: View {
    @EnvironmentObject var authContext: AuthContext

    @State private var sessions: [JSON] = []
    @State private var isLoading = false
    @State private var selectedSessions: Set<String> = []
    @State private var showDeleteConfirmation = false

    private let client = AllAuthClient.shared

    var currentSession: JSON? {
        sessions.first { $0["is_current"].boolValue }
    }

    var otherSessions: [JSON] {
        sessions.filter { !$0["is_current"].boolValue }
    }

    public init() {}

    public var body: some View {
        List {
            // Current session
            if let current = currentSession {
                Section("Current Session") {
                    SessionRow(session: current, isCurrent: true)
                }
            }

            // Other sessions
            if !otherSessions.isEmpty {
                Section {
                    ForEach(Array(otherSessions.enumerated()), id: \.offset) { index, session in
                        SessionRow(session: session, isCurrent: false)
                    }
                    .onDelete(perform: deleteSessions)
                } header: {
                    Text("Other Sessions")
                } footer: {
                    Text("These are other devices or browsers where you're signed in.")
                }

                // Sign out all other sessions
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out All Other Sessions")
                            Spacer()
                        }
                    }
                }
            } else if !isLoading {
                Section {
                    Text("No other active sessions")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadSessions()
        }
        .task {
            await loadSessions()
        }
        .confirmationDialog(
            "Sign out all other sessions?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Sign Out All", role: .destructive) {
                Task { await signOutAllOthers() }
            }
        } message: {
            Text("This will sign out all other devices and browsers.")
        }
    }

    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await client.getSessions()
            if result.isSuccess {
                sessions = result["data"].arrayValue
            }
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        let ids = offsets.map { otherSessions[$0]["id"].stringValue }
        Task {
            do {
                _ = try await client.deleteSessions(ids: ids)
                await loadSessions()
            } catch {
                print("Failed to delete sessions: \(error)")
            }
        }
    }

    private func signOutAllOthers() async {
        let otherIds = otherSessions.map { $0["id"].stringValue }
        guard !otherIds.isEmpty else { return }

        do {
            _ = try await client.deleteSessions(ids: otherIds)
            await loadSessions()
        } catch {
            print("Failed to sign out all: \(error)")
        }
    }
}

/// Row for displaying a session
struct SessionRow: View {
    let session: JSON
    let isCurrent: Bool

    var userAgent: String {
        session["user_agent"].stringValue
    }

    var ip: String {
        session["ip"].stringValue
    }

    var createdAt: Date {
        let timestamp = session["created_at"].doubleValue
        return Date(timeIntervalSince1970: timestamp)
    }

    var lastSeenAt: String {
        session["last_seen_at"].stringValue
    }

    var deviceInfo: (icon: String, description: String) {
        let ua = userAgent.lowercased()

        if ua.contains("iphone") {
            return ("iphone", "iPhone")
        } else if ua.contains("ipad") {
            return ("ipad", "iPad")
        } else if ua.contains("mac") {
            return ("laptopcomputer", "Mac")
        } else if ua.contains("android") {
            return ("candybarphone", "Android")
        } else if ua.contains("windows") {
            return ("pc", "Windows")
        } else if ua.contains("linux") {
            return ("desktopcomputer", "Linux")
        } else {
            return ("globe", "Unknown Device")
        }
    }

    var browserInfo: String {
        let ua = userAgent.lowercased()

        if ua.contains("safari") && !ua.contains("chrome") {
            return "Safari"
        } else if ua.contains("chrome") {
            return "Chrome"
        } else if ua.contains("firefox") {
            return "Firefox"
        } else if ua.contains("edge") {
            return "Edge"
        } else {
            return "Browser"
        }
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: deviceInfo.icon)
                .font(.title2)
                .foregroundColor(isCurrent ? .green : .secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(deviceInfo.description) - \(browserInfo)")
                        .fontWeight(.medium)

                    if isCurrent {
                        Text("(This device)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Text(ip)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Last seen: \(formatLastSeen())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func formatLastSeen() -> String {
        if lastSeenAt.isEmpty {
            return "Unknown"
        }

        // Parse ISO date string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: lastSeenAt) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }

        return lastSeenAt
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionsView()
            .environmentObject(AuthContext.shared)
    }
}
