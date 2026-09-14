import Foundation

enum EmailVerificationDeepLink {
    static func key(from url: URL) -> String? {
        guard url.scheme?.isEmpty == false,
              url.host?.lowercased() == "auth",
              url.path == "/verify-email",
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.fragment == nil,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              queryItems.count == 1,
              queryItems[0].name == "key",
              let key = queryItems[0].value
        else {
            return nil
        }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == key, trimmed.count <= 4_096 else {
            return nil
        }
        return trimmed
    }
}
