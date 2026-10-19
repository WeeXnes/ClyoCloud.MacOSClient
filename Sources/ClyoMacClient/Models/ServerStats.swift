import Foundation

public struct ServerStats: Codable {
    public let used: Int64?
    public let total: Int64?
    public let free: Int64?
    public let ram: RAMStats?
    public let cpu: CPUStats?
    public let username: String?

    public var usedPercentage: Double {
        guard let used = used, let total = total, total > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(used) / Double(total)))
    }

    public var formattedUsed: String {
        guard let used = used else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    }

    public var formattedTotal: String {
        guard let total = total else { return "Unlimited" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    public var formattedFree: String {
        guard let free = free else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }
}

public struct RAMStats: Codable {
    public let total: Int64?
    public let used: Int64?
    public let free: Int64?

    public var usedPercentage: Double {
        guard let used = used, let total = total, total > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(used) / Double(total)))
    }
}

public struct CPUStats: Codable {
    public let model: String?
    public let cores: Int?
    public let load: Double? // 0-100 percentage
}
