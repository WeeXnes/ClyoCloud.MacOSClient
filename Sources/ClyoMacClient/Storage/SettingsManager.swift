import Foundation
import ServiceManagement

public final class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private let syncPairsKey = "clyo_sync_folder_pairs"
    private let serverUrlKey = "clyo_server_url"
    private let usernameKey = "clyo_username"
    private let uploadPathKey = "clyo_default_upload_path"
    private let launchAtLoginKey = "clyo_launch_at_login"

    @Published public var serverUrl: String {
        didSet { UserDefaults.standard.set(serverUrl, forKey: serverUrlKey) }
    }

    @Published public var username: String {
        didSet { UserDefaults.standard.set(username, forKey: usernameKey) }
    }

    @Published public var defaultUploadPath: String {
        didSet { UserDefaults.standard.set(defaultUploadPath, forKey: uploadPathKey) }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: launchAtLoginKey)
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    @Published public var syncFolderPairs: [SyncFolderPair] = [] {
        didSet { saveSyncFolderPairs() }
    }

    private init() {
        self.serverUrl = UserDefaults.standard.string(forKey: serverUrlKey) ?? "http://localhost:6969"
        self.username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        self.defaultUploadPath = UserDefaults.standard.string(forKey: uploadPathKey) ?? ""
        self.launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        self.syncFolderPairs = loadSyncFolderPairs()
    }

    private func loadSyncFolderPairs() -> [SyncFolderPair] {
        guard let data = UserDefaults.standard.data(forKey: syncPairsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([SyncFolderPair].self, from: data)) ?? []
    }

    private func saveSyncFolderPairs() {
        if let data = try? JSONEncoder().encode(syncFolderPairs) {
            UserDefaults.standard.set(data, forKey: syncPairsKey)
        }
    }

    public func addSyncPair(localPath: String, remotePath: String) {
        let pair = SyncFolderPair(localPath: localPath, remotePath: remotePath)
        syncFolderPairs.append(pair)
    }

    public func removeSyncPair(id: UUID) {
        syncFolderPairs.removeAll { $0.id == id }
    }

    public func updateSyncPair(_ pair: SyncFolderPair) {
        if let index = syncFolderPairs.firstIndex(where: { $0.id == pair.id }) {
            syncFolderPairs[index] = pair
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .notRegistered {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Failed to toggle Launch at Login: \(error)")
            }
        }
    }
}
