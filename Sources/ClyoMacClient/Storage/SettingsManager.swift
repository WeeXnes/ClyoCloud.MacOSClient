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

    private var launchAgentURL: URL {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryURL.appendingPathComponent("LaunchAgents").appendingPathComponent("dev.weexnes.clyocloud.plist")
    }

    private init() {
        self.serverUrl = UserDefaults.standard.string(forKey: serverUrlKey) ?? "http://localhost:6969"
        self.username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        self.defaultUploadPath = UserDefaults.standard.string(forKey: uploadPathKey) ?? ""
        self.launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        self.syncFolderPairs = loadSyncFolderPairs()

        let storedLaunchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let agentExists = FileManager.default.fileExists(atPath: libraryURL.appendingPathComponent("LaunchAgents").appendingPathComponent("dev.weexnes.clyocloud.plist").path)

        var smEnabled = false
        if #available(macOS 13.0, *) {
            smEnabled = (SMAppService.mainApp.status == .enabled)
        }

        let shouldBeEnabled = storedLaunchAtLogin || smEnabled || agentExists
        self.launchAtLogin = shouldBeEnabled
        if shouldBeEnabled {
            updateLaunchAtLogin(true)
        }
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
        if enabled {
            if #available(macOS 13.0, *) {
                do {
                    if SMAppService.mainApp.status == .notRegistered {
                        try SMAppService.mainApp.register()
                    }
                } catch {
                    print("SMAppService registration note: \(error)")
                }
            }
            // Always ensure LaunchAgent is in place so autostart works reliably across all environments
            installLaunchAgent()
        } else {
            if #available(macOS 13.0, *) {
                if SMAppService.mainApp.status == .enabled {
                    try? SMAppService.mainApp.unregister()
                }
            }
            removeLaunchAgent()
        }
    }

    private func installLaunchAgent() {
        let launchAgentDir = launchAgentURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: launchAgentDir.path) {
            try? FileManager.default.createDirectory(at: launchAgentDir, withIntermediateDirectories: true)
        }

        let appPath: String
        let mainBundlePath = Bundle.main.bundlePath
        if mainBundlePath.hasSuffix(".app") && FileManager.default.fileExists(atPath: mainBundlePath) {
            appPath = mainBundlePath
        } else if FileManager.default.fileExists(atPath: "/Applications/ClyoCloud.app") {
            appPath = "/Applications/ClyoCloud.app"
        } else {
            appPath = "/Applications/ClyoCloud.app"
        }

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>dev.weexnes.clyocloud</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>-a</string>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """

        do {
            try plistContent.write(to: launchAgentURL, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", "-w", launchAgentURL.path]
            try? process.run()
            print("Successfully installed and loaded LaunchAgent at \(launchAgentURL.path)")
        } catch {
            print("Failed to write LaunchAgent plist: \(error)")
        }
    }

    private func removeLaunchAgent() {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", "-w", launchAgentURL.path]
            try? process.run()
            try? FileManager.default.removeItem(at: launchAgentURL)
        }
    }
}
