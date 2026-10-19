import Foundation

public struct SyncFolderPair: Codable, Identifiable, Hashable {
    public let id: UUID
    public var localPath: String
    public var remotePath: String
    public var isEnabled: Bool
    public var lastSyncTime: Date?
    public var statusDescription: String

    public init(
        id: UUID = UUID(),
        localPath: String,
        remotePath: String,
        isEnabled: Bool = true,
        lastSyncTime: Date? = nil,
        statusDescription: String = "Ready"
    ) {
        self.id = id
        self.localPath = localPath
        self.remotePath = remotePath
        self.isEnabled = isEnabled
        self.lastSyncTime = lastSyncTime
        self.statusDescription = statusDescription
    }

    public var localFolderName: String {
        (localPath as NSString).lastPathComponent
    }

    public var remoteFolderName: String {
        if remotePath.isEmpty || remotePath == "/" {
            return "Root"
        }
        return (remotePath as NSString).lastPathComponent
    }
}

public enum SyncState: Equatable {
    case idle
    case syncing(progress: Double, detail: String)
    case success(Date)
    case error(String)
    case paused
}

public struct SyncManifestItem: Codable {
    public var size: Int64
    public var localMtime: Double
    public var remoteMtime: Double

    public init(size: Int64, localMtime: Double, remoteMtime: Double) {
        self.size = size
        self.localMtime = localMtime
        self.remoteMtime = remoteMtime
    }
}

public struct SyncManifest: Codable {
    public var items: [String: SyncManifestItem] = [:]

    public init(items: [String: SyncManifestItem] = [:]) {
        self.items = items
    }
}

