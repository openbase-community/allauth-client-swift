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
        let redactedMessage = redactSensitiveText(message)
        let redactedMetadata = redactedMetadata(metadata)

        let renderedMetadata = redactedMetadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line: String
        if renderedMetadata.isEmpty {
            line = "[AuthDiagnostics][\(component)] \(redactedMessage)"
        } else {
            line = "[AuthDiagnostics][\(component)] \(redactedMessage) \(renderedMetadata)"
        }

        if isEnabled {
            print(line)
        }

        append(
            Entry(
                timestamp: isoTimestamp(),
                component: component,
                message: redactedMessage,
                metadata: redactedMetadata,
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

    /// Key suffixes whose values must never appear in logs (covers
    /// access_token, refresh_token, session_token, password, secret, key, ...)
    private static let sensitiveKeySuffixes = ["password", "secret", "key", "token"]
    private static let sensitiveKeyNames = ["authorization", "x-session-token"]
    private static let sensitiveKeyPattern = "(?:password|secret|key|token)"

    static func isSensitiveKey(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return sensitiveKeyNames.contains(lowered)
            || sensitiveKeySuffixes.contains { lowered.hasSuffix($0) }
    }

    /// Mask values of sensitive keys in logged JSON or query/form text
    public static func redactSensitiveText(_ value: String) -> String {
        var redacted = value

        // JSON-style pairs: "access_token": "..."
        redacted = redacted.replacingOccurrences(
            of: "(\"[\\w-]*\(sensitiveKeyPattern)\"\\s*:\\s*)\"[^\"]*\"",
            with: "$1\"<redacted>\"",
            options: [.regularExpression, .caseInsensitive]
        )

        // Query/form-style pairs: access_token=...
        redacted = redacted.replacingOccurrences(
            of: "([\\w-]*\(sensitiveKeyPattern)=)[^&\\s\"]+",
            with: "$1<redacted>",
            options: [.regularExpression, .caseInsensitive]
        )

        redacted = redacted.replacingOccurrences(
            of: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
            with: "<redacted-email>",
            options: [.regularExpression, .caseInsensitive]
        )

        return redacted
    }

    /// Summarize an endpoint URL, masking sensitive query parameter values
    public static func endpointSummary(_ url: String) -> String {
        guard var components = URLComponents(string: url) else {
            return redactSensitiveText(url)
        }

        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems.map { item in
                guard let value = item.value, !value.isEmpty, isSensitiveKey(item.name) else {
                    return item
                }
                return URLQueryItem(name: item.name, value: "<redacted>")
            }
        }

        return components.string ?? redactSensitiveText(url)
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

    private static func redactedMetadata(_ metadata: [String: String]) -> [String: String] {
        var redacted: [String: String] = [:]
        for (key, value) in metadata {
            redacted[key] = isSensitiveKey(key) ? "<redacted>" : redactSensitiveText(value)
        }
        return redacted
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
