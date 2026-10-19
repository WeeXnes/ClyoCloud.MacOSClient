import Foundation

public enum TransferType: String, Codable {
    case upload
    case download
    case sync
    case clipboard
}

public enum TransferStatus: Equatable {
    case pending
    case inProgress(progress: Double)
    case completed
    case failed(String)
}

public struct TransferItem: Identifiable {
    public let id: UUID
    public let name: String
    public let size: Int64
    public var progress: Double
    public let type: TransferType
    public var status: TransferStatus
    public let date: Date

    public init(
        id: UUID = UUID(),
        name: String,
        size: Int64 = 0,
        progress: Double = 0.0,
        type: TransferType,
        status: TransferStatus = .pending,
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.progress = progress
        self.type = type
        self.status = status
        self.date = date
    }

    public var formattedSize: String {
        if size <= 0 { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
