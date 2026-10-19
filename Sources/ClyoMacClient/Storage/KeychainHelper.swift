import Foundation
import Security

public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let service = "dev.weexnes.clyocloud.mac"

    // In-memory token cache to completely avoid repeated disk or keychain queries
    private var memoryCache: [String: String] = [:]

    private init() {
        // Clean up any old Keychain item that triggers macOS security prompts
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    public func save(token: String, for account: String) {
        memoryCache[account] = token
        UserDefaults.standard.set(token, forKey: "clyo_token_\(account)")
        saveToAppSupport(token: token, account: account)
    }

    public func readToken(for account: String) -> String? {
        // 1. In-memory cache first (instant, 0ms, zero OS prompts)
        if let token = memoryCache[account], !token.isEmpty {
            return token
        }

        // 2. Private App Support storage
        if let token = readFromAppSupport(account: account), !token.isEmpty {
            memoryCache[account] = token
            return token
        }

        // 3. UserDefaults fallback
        if let token = UserDefaults.standard.string(forKey: "clyo_token_\(account)"), !token.isEmpty {
            memoryCache[account] = token
            return token
        }

        return nil
    }

    public func deleteToken(for account: String) {
        memoryCache.removeValue(forKey: account)
        UserDefaults.standard.removeObject(forKey: "clyo_token_\(account)")
        deleteFromAppSupport(account: account)
    }

    private var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("dev.weexnes.clyocloud", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func tokenFileURL(for account: String) -> URL {
        storageDirectory.appendingPathComponent("token_\(account).dat")
    }

    private func saveToAppSupport(token: String, account: String) {
        let url = tokenFileURL(for: account)
        if let data = token.data(using: .utf8) {
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    private func readFromAppSupport(account: String) -> String? {
        let url = tokenFileURL(for: account)
        guard let data = try? Data(contentsOf: url),
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    private func deleteFromAppSupport(account: String) {
        let url = tokenFileURL(for: account)
        try? FileManager.default.removeItem(at: url)
    }
}
