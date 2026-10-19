import Foundation

public final class SyncManifestManager {
    public static let shared = SyncManifestManager()

    private let manifestsDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.manifestsDirectory = appSupport.appendingPathComponent("dev.weexnes.clyocloud/manifests", isDirectory: true)
        try? FileManager.default.createDirectory(at: manifestsDirectory, withIntermediateDirectories: true)
    }

    private func manifestURL(for pairId: UUID) -> URL {
        manifestsDirectory.appendingPathComponent("\(pairId.uuidString).json")
    }

    public func loadManifest(for pairId: UUID) -> SyncManifest {
        let url = manifestURL(for: pairId)
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(SyncManifest.self, from: data) else {
            return SyncManifest()
        }
        return manifest
    }

    public func saveManifest(_ manifest: SyncManifest, for pairId: UUID) {
        let url = manifestURL(for: pairId)
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func removeManifest(for pairId: UUID) {
        let url = manifestURL(for: pairId)
        try? FileManager.default.removeItem(at: url)
    }
}
