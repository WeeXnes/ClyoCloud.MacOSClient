import Foundation
import SwiftUI
import Combine

public enum ActiveTab: String, CaseIterable, Identifiable {
    case upload = "Upload"
    case wallpapers = "Wallpapers"
    case sync = "Sync"
    case settings = "Settings"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .upload: return "arrow.up.circle.fill"
        case .wallpapers: return "photo.fill.on.rectangle.fill"
        case .sync: return "arrow.triangle.2.circlepath.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: String = ""
    @Published public var selectedTab: ActiveTab = .upload
    @Published public var serverStats: ServerStats? = nil
    @Published public var recentTransfers: [TransferItem] = []
    @Published public var isRefreshing: Bool = false
    @Published public var remoteFolders: [String] = ["/"]

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.currentUser = SettingsManager.shared.username
        checkExistingAuth()
    }

    public func checkExistingAuth() {
        let username = SettingsManager.shared.username
        guard !username.isEmpty else {
            self.isAuthenticated = false
            return
        }
        let token = KeychainHelper.shared.readToken(for: username)
        if let token = token, !token.isEmpty {
            self.isAuthenticated = true
            self.currentUser = username
            Task {
                await refreshData()
                SyncEngine.shared.start()
            }
        } else {
            self.isAuthenticated = false
        }
    }

    public func loginWithDevicePayload(_ payloadString: String) async -> (success: Bool, message: String) {
        guard let payload = DevicePayload.parse(from: payloadString) else {
            // Check if user entered raw token
            let rawToken = payloadString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawToken.isEmpty && rawToken.contains(".") { // JWT format check
                let username = SettingsManager.shared.username.isEmpty ? "mac_user" : SettingsManager.shared.username
                KeychainHelper.shared.save(token: rawToken, for: username)
                self.currentUser = username
                self.isAuthenticated = true
                await refreshData()
                SyncEngine.shared.start()
                return (true, "Logged in via Token!")
            }
            return (false, "Invalid QR payload or token format")
        }

        SettingsManager.shared.serverUrl = payload.serverUrl
        SettingsManager.shared.username = payload.username
        KeychainHelper.shared.save(token: payload.token, for: payload.username)

        self.currentUser = payload.username
        self.isAuthenticated = true
        await refreshData()
        SyncEngine.shared.start()
        return (true, "Connected to \(payload.serverUrl)!")
    }

    public func loginWithCredentials(username: String, password: String) async -> (success: Bool, requires2fa: Bool, tempToken: String?, message: String) {
        do {
            let res = try await ClyoAPIClient.shared.login(username: username, password: password)
            if res.requires2fa {
                return (false, true, res.tempToken, "Two-factor code required")
            }
            if let token = res.token {
                SettingsManager.shared.username = username
                KeychainHelper.shared.save(token: token, for: username)
                self.currentUser = username
                self.isAuthenticated = true
                await refreshData()
                SyncEngine.shared.start()
                return (true, false, nil, "Logged in successfully!")
            }
            return (false, false, nil, "Login failed")
        } catch {
            return (false, false, nil, error.localizedDescription)
        }
    }

    public func verify2FA(tempToken: String, code: String, username: String) async -> (success: Bool, message: String) {
        do {
            let token = try await ClyoAPIClient.shared.verify2FA(tempToken: tempToken, code: code)
            SettingsManager.shared.username = username
            KeychainHelper.shared.save(token: token, for: username)
            self.currentUser = username
            self.isAuthenticated = true
            await refreshData()
            SyncEngine.shared.start()
            return (true, "Verified and logged in!")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func logout() {
        if !currentUser.isEmpty {
            KeychainHelper.shared.deleteToken(for: currentUser)
        }
        self.isAuthenticated = false
        self.currentUser = ""
        self.serverStats = nil
        self.recentTransfers = []
    }

    public func refreshData() async {
        guard isAuthenticated else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let statsTask = try? ClyoAPIClient.shared.fetchStats()
        async let filesTask = try? ClyoAPIClient.shared.fetchFiles(path: "")

        let (stats, files) = await (statsTask, filesTask)
        if let stats = stats {
            self.serverStats = stats
        }
        if let files = files {
            let folders = files.filter { $0.isFolder }.map { $0.name }
            self.remoteFolders = ["/"] + folders
        }
    }

    public func updateTransferProgress(id: UUID, progress: Double) {
        if let index = recentTransfers.firstIndex(where: { $0.id == id }) {
            var item = recentTransfers[index]
            item.progress = progress
            item.status = .inProgress(progress: progress)
            recentTransfers[index] = item
        }
    }

    public func completeTransfer(id: UUID) {
        if let index = recentTransfers.firstIndex(where: { $0.id == id }) {
            var item = recentTransfers[index]
            item.progress = 1.0
            item.status = .completed
            recentTransfers[index] = item
        }
    }

    public func failTransfer(id: UUID, error: String) {
        if let index = recentTransfers.firstIndex(where: { $0.id == id }) {
            var item = recentTransfers[index]
            item.status = .failed(error)
            recentTransfers[index] = item
        }
    }

    public func uploadFiles(_ urls: [URL], destination: String = "") async {
        guard !urls.isEmpty else { return }
        let targetPath = destination == "/" ? "" : destination

        for url in urls {
            let name = url.lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

            let transfer = TransferItem(
                name: name,
                size: size,
                progress: 0.1,
                type: .upload,
                status: .inProgress(progress: 0.1)
            )
            let transferId = transfer.id
            recentTransfers.insert(transfer, at: 0)

            do {
                try await ClyoAPIClient.shared.upload(files: [url], toPath: targetPath) { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.updateTransferProgress(id: transferId, progress: progress)
                    }
                }
                completeTransfer(id: transferId)
            } catch {
                failTransfer(id: transferId, error: error.localizedDescription)
            }
        }

        await refreshData()
    }
}
