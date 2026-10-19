import Foundation
import Security

public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let service = "dev.weexnes.clyocloud.mac"

    private init() {}

    public func save(token: String, for account: String) {
        if let data = token.data(using: .utf8) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }
        // Also save to user defaults as fallback for CLI/unsigned testing
        UserDefaults.standard.set(token, forKey: "clyo_token_\(account)")
    }

    public func readToken(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let token = String(data: data, encoding: .utf8) {
            return token
        }

        // Fallback
        return UserDefaults.standard.string(forKey: "clyo_token_\(account)")
    }

    public func deleteToken(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "clyo_token_\(account)")
    }
}
