import Foundation
import AppKit

public final class WallpaperManager: ObservableObject {
    public static let shared = WallpaperManager()

    @Published public var wallpapers: [ClyoFile] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var currentSettingWallpaperName: String? = nil

    private let cacheDirectory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("dev.weexnes.clyocloud/wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    @MainActor
    public func loadWallpapers() async {
        isLoading = true
        errorMessage = nil
        do {
            wallpapers = try await ClyoAPIClient.shared.fetchWallpapers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    public func setAsDesktopWallpaper(file: ClyoFile) async -> Bool {
        currentSettingWallpaperName = file.name
        defer { currentSettingWallpaperName = nil }

        let localURL = cacheDirectory.appendingPathComponent(file.name)
        do {
            // Download full image if not cached or size mismatch
            let needsDownload: Bool
            if FileManager.default.fileExists(atPath: localURL.path) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
                let localSize = attrs?[.size] as? Int64 ?? 0
                needsDownload = (localSize != file.size)
            } else {
                needsDownload = true
            }

            if needsDownload {
                try await ClyoAPIClient.shared.downloadFile(remotePath: file.name, to: localURL)
            }

            // Apply wallpaper to all screens
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(localURL, for: screen, options: [:])
            }

            return true
        } catch {
            errorMessage = "Failed to set wallpaper: \(error.localizedDescription)"
            return false
        }
    }
}
