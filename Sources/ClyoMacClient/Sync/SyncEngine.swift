import Foundation

public final class SyncEngine: ObservableObject {
    public static let shared = SyncEngine()

    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var statusMessage: String = "All folders up to date"

    private var watcher: FSEventWatcher?
    private var periodicTimer: Timer?
    private var debounceTimer: Timer?

    private let ignoredFiles: Set<String> = [
        ".DS_Store",
        ".localized",
        ".cloudinfo",
        "Thumbs.db",
        "desktop.ini"
    ]

    private init() {}

    public func start() {
        restartWatcher()
        startPeriodicTimer()
    }

    public func restartWatcher() {
        watcher?.stop()
        let paths = SettingsManager.shared.syncFolderPairs
            .filter { $0.isEnabled }
            .map { $0.localPath }
            .filter { FileManager.default.fileExists(atPath: $0) }

        guard !paths.isEmpty else { return }

        watcher = FSEventWatcher(paths: paths, latency: 1.5) { [weak self] in
            self?.handleLocalChanges()
        }
        watcher?.start()
    }

    private func handleLocalChanges() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                await SyncEngine.shared.syncAll()
            }
        }
    }

    private func startPeriodicTimer() {
        periodicTimer?.invalidate()
        // Poll for remote changes every 60 seconds
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                await SyncEngine.shared.syncAll()
            }
        }
    }

    @MainActor
    public func syncAll() async {
        guard !isSyncing else { return }
        let pairs = SettingsManager.shared.syncFolderPairs.filter { $0.isEnabled }
        guard !pairs.isEmpty else {
            statusMessage = "No synced folders configured"
            return
        }

        isSyncing = true
        statusMessage = "Syncing folders..."
        defer { isSyncing = false }

        for pair in pairs {
            await syncPair(pair)
        }

        lastSyncDate = Date()
        statusMessage = "All folders up to date"
    }

    @MainActor
    private func syncPair(_ pair: SyncFolderPair) async {
        let localURL = URL(fileURLWithPath: pair.localPath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: localURL.path) else {
            var updated = pair
            updated.statusDescription = "Local folder not found"
            SettingsManager.shared.updateSyncPair(updated)
            return
        }

        var currentPair = pair
        currentPair.statusDescription = "Syncing..."
        SettingsManager.shared.updateSyncPair(currentPair)

        do {
            // 1. Fetch remote files
            let remoteFiles = try await ClyoAPIClient.shared.fetchFiles(path: pair.remotePath)
            let remoteDict = Dictionary(uniqueKeysWithValues: remoteFiles.map { ($0.name, $0) })

            // 2. Scan local files
            let localItemNames = try fileManager.contentsOfDirectory(atPath: localURL.path)
                .filter { shouldSyncItem(name: $0) }

            var localDict: [String: (url: URL, size: Int64, mtime: Date)] = [:]
            for name in localItemNames {
                let itemURL = localURL.appendingPathComponent(name)
                let attrs = try fileManager.attributesOfItem(atPath: itemURL.path)
                let size = (attrs[.size] as? Int64) ?? 0
                let mtime = (attrs[.modificationDate] as? Date) ?? Date()
                localDict[name] = (itemURL, size, mtime)
            }

            // 3. Local to Remote: Upload new or modified local files
            for (name, localInfo) in localDict {
                if let remote = remoteDict[name] {
                    // Check if local file is newer and size changed
                    let remoteDate = remote.modifiedDate
                    let timeDiff = localInfo.mtime.timeIntervalSince(remoteDate)

                    if timeDiff > 3.0 && localInfo.size != remote.size {
                        // Local is newer -> Upload
                        try await ClyoAPIClient.shared.upload(files: [localInfo.url], toPath: pair.remotePath)
                    }
                } else {
                    // Not on remote -> Upload
                    try await ClyoAPIClient.shared.upload(files: [localInfo.url], toPath: pair.remotePath)
                }
            }

            // 4. Remote to Local: Download new or modified remote files
            for (name, remote) in remoteDict where !remote.isFolder {
                guard shouldSyncItem(name: name) else { continue }
                let destinationURL = localURL.appendingPathComponent(name)

                if let localInfo = localDict[name] {
                    let remoteDate = remote.modifiedDate
                    let timeDiff = remoteDate.timeIntervalSince(localInfo.mtime)

                    if timeDiff > 3.0 && remote.size != localInfo.size {
                        // Remote is newer -> Download
                        try await ClyoAPIClient.shared.downloadFile(
                            remotePath: pair.remotePath.isEmpty ? name : "\(pair.remotePath)/\(name)",
                            to: destinationURL
                        )
                    }
                } else {
                    // Missing locally -> Download
                    try await ClyoAPIClient.shared.downloadFile(
                        remotePath: pair.remotePath.isEmpty ? name : "\(pair.remotePath)/\(name)",
                        to: destinationURL
                    )
                }
            }

            currentPair.lastSyncTime = Date()
            currentPair.statusDescription = "In Sync"
            SettingsManager.shared.updateSyncPair(currentPair)

        } catch {
            print("Sync error on pair \(pair.localFolderName): \(error)")
            currentPair.statusDescription = "Sync error: \(error.localizedDescription)"
            SettingsManager.shared.updateSyncPair(currentPair)
        }
    }

    private func shouldSyncItem(name: String) -> Bool {
        if ignoredFiles.contains(name) { return false }
        if name.hasPrefix(".") { return false }
        if name.hasSuffix(".cloudinfo") { return false }
        if name.hasSuffix(".crdownload") || name.hasSuffix(".tmp") { return false }
        return true
    }
}
