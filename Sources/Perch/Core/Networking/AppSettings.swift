import Foundation
import Security

// Only the Perch backend URL belongs in preferences. Provider secrets never enter the app.
enum AppSettings {
    static var baseURL: URL? {
        let raw = UserDefaults.standard.string(forKey: "perch.backendURL")
            ?? Bundle.main.object(forInfoDictionaryKey: "PerchAPIBaseURL") as? String ?? ""
        guard let url = URL(string: raw), let host = url.host,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else { return nil }
        return url
    }

    static var backendToken: String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.perch.backend", kSecAttrAccount as String: "personal-token",
                                    kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveBackend(url rawURL: String, token: String) throws {
        let rawURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawURL.isEmpty {
            guard let url = URL(string: rawURL), let host = url.host,
                  url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else {
                throw NetworkError.invalidURL
            }
        }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.perch.backend", kSecAttrAccount as String: "personal-token"]
        // Update the keychain before preferences so failure leaves configuration unchanged.
        if token.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw NetworkError.configurationFailed }
        } else {
            let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8),
                                            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw NetworkError.configurationFailed }
            } else if status != errSecSuccess { throw NetworkError.configurationFailed }
        }
        UserDefaults.standard.set(rawURL, forKey: "perch.backendURL")
    }
}
