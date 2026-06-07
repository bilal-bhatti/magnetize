// Keychain.swift — Transmission credentials in the macOS login keychain.
// Same service name ("magnetize") the legacy shell engine used, so an existing
// install's stored credentials are picked up unchanged.

import Foundation
import Security

enum Keychain {
    static let service = "magnetize"

    struct Credentials {
        var username: String
        var password: String
    }

    static func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let dict = item as? [String: Any],
              let data = dict[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8),
              let account = dict[kSecAttrAccount as String] as? String
        else { return nil }
        return Credentials(username: account, password: password)
    }

    static func save(_ creds: Credentials) {
        delete() // simplest correct upsert: clear then add
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: creds.username,
            kSecValueData as String: Data(creds.password.utf8),
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
