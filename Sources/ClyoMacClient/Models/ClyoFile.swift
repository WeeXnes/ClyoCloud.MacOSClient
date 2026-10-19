import Foundation

public struct ClyoFile: Codable, Identifiable, Hashable {
    public var id: String { name + "\(lastModified)" }
    public let name: String
    public let size: Int64
    public let type: String
    public let meta: FileMeta
    public let lastModified: Int64
    public let isFolder: Bool

    public var modifiedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(lastModified) / 1000.0)
    }

    public var formattedSize: String {
        if isFolder { return "Folder" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }

    public var isImage: Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg"].contains(ext)
    }

    public var isVideo: Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["mp4", "webm", "mov", "mkv", "avi", "m4v"].contains(ext)
    }

    public var isAudio: Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["mp3", "wav", "flac", "aac", "ogg", "m4a"].contains(ext)
    }
}

public struct FileMeta: Codable, Hashable {
    public let tags: [Tag]?
    public let description: String?
    public let isPublic: Bool?
    public let isFavourite: Bool?
    public let isWallpaper: Bool?
    public let isPhotoWidget: Bool?
    public let previewImage: String?

    public init(
        tags: [Tag]? = nil,
        description: String? = nil,
        isPublic: Bool? = nil,
        isFavourite: Bool? = nil,
        isWallpaper: Bool? = nil,
        isPhotoWidget: Bool? = nil,
        previewImage: String? = nil
    ) {
        self.tags = tags
        self.description = description
        self.isPublic = isPublic
        self.isFavourite = isFavourite
        self.isWallpaper = isWallpaper
        self.isPhotoWidget = isPhotoWidget
        self.previewImage = previewImage
    }
}

public struct Tag: Codable, Hashable {
    public let name: String
    public let color: String
}
