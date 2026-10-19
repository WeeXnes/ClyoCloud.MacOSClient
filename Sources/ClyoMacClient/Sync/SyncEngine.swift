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
            // Load state manifest
            var manifest = SyncManifestManager.shared.loadManifest(for: pair.id)

            // 1. Fetch remote files
            let remoteFiles = try await ClyoAPIClient.shared.fetchFiles(path: pair.remotePath)
            var remoteDict = Dictionary(uniqueKeysWithValues: remoteFiles.filter { !$0.isFolder }.map { ($0.name, $0) })

            // 2. Scan local files
            let localItemNames = try fileManager.contentsOfDirectory(atPath: localURL.path)
                .filter { shouldSyncItem(name: $0) }

            var localDict: [String: (url: URL, size: Int64, mtime: Date)] = [:]
            for name in localItemNames {
                let itemURL = localURL.appendingPathComponent(name)
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), !isDir.boolValue {
                    let attrs = try fileManager.attributesOfItem(atPath: itemURL.path)
                    let size = (attrs[.size] as? Int64) ?? 0
                    let mtime = (attrs[.modificationDate] as? Date) ?? Date()
                    localDict[name] = (itemURL, size, mtime)
                }
            }

            // 3. Phase 1: Local Rename Detection
            let missingLocalNames = manifest.items.keys.filter { localDict[$0] == nil && remoteDict[$0] != nil }
            let newLocalNames = localDict.keys.filter { manifest.items[$0] == nil && remoteDict[$0] == nil }

            for oldName in missingLocalNames {
                guard let oldManifestItem = manifest.items[oldName] else { continue }
                if let matchingNewName = newLocalNames.first(where: { localDict[$0]?.size == oldManifestItem.size }) {
                    let oldRemotePath = pair.remotePath.isEmpty ? oldName : "\(pair.remotePath)/\(oldName)"
                    do {
                        try await ClyoAPIClient.shared.renameFile(oldPath: oldRemotePath, newName: matchingNewName)
                        manifest.items.removeValue(forKey: oldName)
                        if let localInfo = localDict[matchingNewName] {
                            manifest.items[matchingNewName] = SyncManifestItem(
                                size: localInfo.size,
                                localMtime: localInfo.mtime.timeIntervalSince1970,
                                remoteMtime: Date().timeIntervalSince1970
                            )
                        }
                        if let oldRemote = remoteDict.removeValue(forKey: oldName) {
                            let updatedRemote = ClyoFile(
                                name: matchingNewName,
                                size: oldRemote.size,
                                type: oldRemote.type,
                                meta: oldRemote.meta,
                                lastModified: Int64(Date().timeIntervalSince1970 * 1000),
                                isFolder: false
                            )
                            remoteDict[matchingNewName] = updatedRemote
                        }
                    } catch {
                        print("Rename optimization failed, will fallback to delete/upload: \(error)")
                    }
                }
            }

            // 4. Phase 2: 3-Way Reconciliation
            let allNames = Set(localDict.keys).union(remoteDict.keys).union(manifest.items.keys)

            for name in allNames {
                guard shouldSyncItem(name: name) else { continue }

                let local = localDict[name]
                let remote = remoteDict[name]
                let last = manifest.items[name]
                let remoteFullPath = pair.remotePath.isEmpty ? name : "\(pair.remotePath)/\(name)"
                let itemLocalURL = localURL.appendingPathComponent(name)

                if let local = local, let remote = remote, let last = last {
                    // Scenario A: Exists in Local, Remote, and Manifest
                    let localChanged = (abs(local.mtime.timeIntervalSince1970 - last.localMtime) > 2.0 || local.size != last.size)
                    let remoteChanged = (abs(remote.modifiedDate.timeIntervalSince1970 - last.remoteMtime) > 2.0 || remote.size != last.size)

                    if localChanged && !remoteChanged {
                        // Local modified -> Upload
                        try await ClyoAPIClient.shared.upload(files: [local.url], toPath: pair.remotePath)
                        manifest.items[name] = SyncManifestItem(
                            size: local.size,
                            localMtime: local.mtime.timeIntervalSince1970,
                            remoteMtime: Date().timeIntervalSince1970
                        )
                    } else if remoteChanged && !localChanged {
                        // Remote modified -> Download
                        try await ClyoAPIClient.shared.downloadFile(remotePath: remoteFullPath, to: local.url)
                        let newLocalMtime = (try? fileManager.attributesOfItem(atPath: local.url.path)[.modificationDate] as? Date) ?? Date()
                        manifest.items[name] = SyncManifestItem(
                            size: remote.size,
                            localMtime: newLocalMtime.timeIntervalSince1970,
                            remoteMtime: remote.modifiedDate.timeIntervalSince1970
                        )
                    } else if localChanged && remoteChanged {
                        // Conflict! Preserve local file, download remote file
                        let ext = (name as NSString).pathExtension
                        let base = (name as NSString).deletingPathExtension
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd_HHmmss"
                        let conflictName = "\(base) (Mac Conflict \(formatter.string(from: Date()))).\(ext)"
                        let conflictURL = localURL.appendingPathComponent(conflictName)

                        try? fileManager.moveItem(at: local.url, to: conflictURL)
                        try await ClyoAPIClient.shared.downloadFile(remotePath: remoteFullPath, to: local.url)

                        let newLocalMtime = (try? fileManager.attributesOfItem(atPath: local.url.path)[.modificationDate] as? Date) ?? Date()
                        manifest.items[name] = SyncManifestItem(
                            size: remote.size,
                            localMtime: newLocalMtime.timeIntervalSince1970,
                            remoteMtime: remote.modifiedDate.timeIntervalSince1970
                        )
                        if let conflictAttrs = try? fileManager.attributesOfItem(atPath: conflictURL.path) {
                            let cSize = (conflictAttrs[.size] as? Int64) ?? 0
                            let cMtime = (conflictAttrs[.modificationDate] as? Date) ?? Date()
                            manifest.items[conflictName] = SyncManifestItem(
                                size: cSize,
                                localMtime: cMtime.timeIntervalSince1970,
                                remoteMtime: 0
                            )
                        }
                    }

                } else if let local = local, last != nil, remote == nil {
                    // Scenario B: In Local and Manifest, but REMOVED on Remote
                    let localChanged = (abs(local.mtime.timeIntervalSince1970 - (last?.localMtime ?? 0)) > 2.0 || local.size != last?.size)
                    if !localChanged {
                        // Deleted on remote -> delete locally
                        try? fileManager.removeItem(at: local.url)
                        manifest.items.removeValue(forKey: name)
                    } else {
                        // Locally modified while remotely deleted -> re-upload to remote
                        try await ClyoAPIClient.shared.upload(files: [local.url], toPath: pair.remotePath)
                        manifest.items[name] = SyncManifestItem(
                            size: local.size,
                            localMtime: local.mtime.timeIntervalSince1970,
                            remoteMtime: Date().timeIntervalSince1970
                        )
                    }

                } else if let remote = remote, last != nil, local == nil {
                    // Scenario C: In Remote and Manifest, but DELETED on Local
                    let remoteChanged = (abs(remote.modifiedDate.timeIntervalSince1970 - (last?.remoteMtime ?? 0)) > 2.0 || remote.size != last?.size)
                    if !remoteChanged {
                        // Deleted on local -> delete remotely
                        try await ClyoAPIClient.shared.deleteFile(path: remoteFullPath)
                        manifest.items.removeValue(forKey: name)
                    } else {
                        // Remotely modified while locally deleted -> re-download
                        try await ClyoAPIClient.shared.downloadFile(remotePath: remoteFullPath, to: itemLocalURL)
                        let newLocalMtime = (try? fileManager.attributesOfItem(atPath: itemLocalURL.path)[.modificationDate] as? Date) ?? Date()
                        manifest.items[name] = SyncManifestItem(
                            size: remote.size,
                            localMtime: newLocalMtime.timeIntervalSince1970,
                            remoteMtime: remote.modifiedDate.timeIntervalSince1970
                        )
                    }

                } else if local == nil && remote == nil && last != nil {
                    // Scenario D: Gone from both
                    manifest.items.removeValue(forKey: name)

                } else if let local = local, let remote = remote, last == nil {
                    // Scenario E: In Local and Remote, but not in manifest (First time merge)
                    let timeDiff = local.mtime.timeIntervalSince(remote.modifiedDate)
                    if timeDiff > 3.0 && local.size != remote.size {
                        // Local is newer -> Upload
                        try await ClyoAPIClient.shared.upload(files: [local.url], toPath: pair.remotePath)
                        manifest.items[name] = SyncManifestItem(
                            size: local.size,
                            localMtime: local.mtime.timeIntervalSince1970,
                            remoteMtime: Date().timeIntervalSince1970
                        )
                    } else if timeDiff < -3.0 && local.size != remote.size {
                        // Remote is newer -> Download
                        try await ClyoAPIClient.shared.downloadFile(remotePath: remoteFullPath, to: local.url)
                        let newLocalMtime = (try? fileManager.attributesOfItem(atPath: local.url.path)[.modificationDate] as? Date) ?? Date()
                        manifest.items[name] = SyncManifestItem(
                            size: remote.size,
                            localMtime: newLocalMtime.timeIntervalSince1970,
                            remoteMtime: remote.modifiedDate.timeIntervalSince1970
                        )
                    } else {
                        // Identical / compatible -> adopt
                        manifest.items[name] = SyncManifestItem(
                            size: local.size,
                            localMtime: local.mtime.timeIntervalSince1970,
                            remoteMtime: remote.modifiedDate.timeIntervalSince1970
                        )
                    }

                } else if let local = local, remote == nil, last == nil {
                    // Scenario F: Brand new local file
                    try await ClyoAPIClient.shared.upload(files: [local.url], toPath: pair.remotePath)
                    manifest.items[name] = SyncManifestItem(
                        size: local.size,
                        localMtime: local.mtime.timeIntervalSince1970,
                        remoteMtime: Date().timeIntervalSince1970
                    )

                } else if let remote = remote, local == nil, last == nil {
                    // Scenario G: Brand new remote file
                    try await ClyoAPIClient.shared.downloadFile(remotePath: remoteFullPath, to: itemLocalURL)
                    let newLocalMtime = (try? fileManager.attributesOfItem(atPath: itemLocalURL.path)[.modificationDate] as? Date) ?? Date()
                    manifest.items[name] = SyncManifestItem(
                        size: remote.size,
                        localMtime: newLocalMtime.timeIntervalSince1970,
                        remoteMtime: remote.modifiedDate.timeIntervalSince1970
                    )
                }
            }

            // Save updated manifest
            SyncManifestManager.shared.saveManifest(manifest, for: pair.id)

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
