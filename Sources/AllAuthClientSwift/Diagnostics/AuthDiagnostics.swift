import Foundation
import SwiftyJSON

public enum AuthDiagnostics {
    public struct Entry: Codable, Equatable {
        public let timestamp: String
        public let component: String
        public let message: String
        public let metadata: [String: String]
        public let line: String
    }

    public static let maxBufferedEntries = 1000
    private static let enabledDefaultsKey = "OpenbaseAuthDiagnosticsEnabled"
    private static let enabledEnvironmentKey = "OPENBASE_AUTH_DIAGNOSTICS"
    private static let entriesLock = NSLock()
    nonisolated(unsafe) private static var entries: [Entry] = []

    public static var isEnabled: Bool {
        let environmentValue = ProcessInfo.processInfo.environment[enabledEnvironmentKey]?.lowercased()
        if environmentValue == "1" || environmentValue == "true" || environmentValue == "yes" {
            return true
        }
        return UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    public static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledDefaultsKey)
    }

    public static func log(_ component: String, _ message: String, metadata: [String: String] = [:]) {
        guard isEnabled else {
            return
        }

        let renderedMetadata = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line: String
        if renderedMetadata.isEmpty {
            line = "[AuthDiagnostics][\(component)] \(message)"
        } else {
            line = "[AuthDiagnostics][\(component)] \(message) \(renderedMetadata)"
        }
        print(line)

        append(
            Entry(
                timestamp: isoTimestamp(),
                component: component,
                message: message,
                metadata: metadata,
                line: line
            )
        )
    }

    public static func recentEntries(limit: Int = maxBufferedEntries) -> [Entry] {
        entriesLock.lock()
        defer { entriesLock.unlock() }
        return Array(entries.suffix(max(0, limit)))
    }

    public static func clearBufferedEntries() {
        entriesLock.lock()
        entries.removeAll()
        entriesLock.unlock()
    }

    public static func uploadPayloadEntries(limit: Int = maxBufferedEntries) -> [[String: Any]] {
        recentEntries(limit: limit).map { entry in
            [
                "timestamp": entry.timestamp,
                "component": entry.component,
                "message": entry.message,
                "metadata": entry.metadata,
                "line": entry.line,
            ]
        }
    }

    public static func redactSensitiveText(_ value: String) -> String {
        value
    }

    public static func endpointSummary(_ url: String) -> String {
        url
    }

    public static func tokenSummary(_ token: String?) -> String {
        guard let token, !token.isEmpty else {
            return "absent"
        }
        return "present length=\(token.count)"
    }

    public static func authHeaderSummary(accessToken: String?, sessionToken: String?) -> String {
        if let accessToken, !accessToken.isEmpty {
            return "bearer \(tokenSummary(accessToken))"
        }
        if let sessionToken, !sessionToken.isEmpty {
            return "session \(tokenSummary(sessionToken))"
        }
        return "none"
    }

    public static func responseSummary(_ json: JSON) -> String {
        var parts: [String] = []

        if json["status"].exists() {
            parts.append("status=\(json["status"].intValue)")
        }
        if json["meta"]["is_authenticated"].exists() {
            parts.append("authenticated=\(json["meta"]["is_authenticated"].boolValue)")
        }

        let flows = json["data"]["flows"].arrayValue.compactMap { $0["id"].string }
        if !flows.isEmpty {
            parts.append("flows=\(flows.joined(separator: ","))")
        }

        let hasAccessToken = (json["data"]["access_token"].string ?? json["meta"]["access_token"].string) != nil
        let hasRefreshToken = (json["data"]["refresh_token"].string ?? json["meta"]["refresh_token"].string) != nil
        if hasAccessToken || hasRefreshToken {
            parts.append("has_access_token=\(hasAccessToken)")
            parts.append("has_refresh_token=\(hasRefreshToken)")
        }

        let errorCount = json["errors"].arrayValue.count
        if errorCount > 0 {
            parts.append("error_count=\(errorCount)")
        }

        return parts.isEmpty ? "json_keys=\(json.dictionaryValue.keys.sorted().joined(separator: ","))" : parts.joined(separator: " ")
    }

    public static func bodySummary(_ data: [String: Any]?) -> String {
        guard let data, !data.isEmpty else {
            return "none"
        }
        return "keys=\(data.keys.sorted().joined(separator: ","))"
    }

    private static func append(_ entry: Entry) {
        entriesLock.lock()
        entries.append(entry)
        if entries.count > maxBufferedEntries {
            entries.removeFirst(entries.count - maxBufferedEntries)
        }
        entriesLock.unlock()
    }

    private static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
