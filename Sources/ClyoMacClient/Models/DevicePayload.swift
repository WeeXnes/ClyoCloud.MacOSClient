import Foundation

public struct DevicePayload: Codable {
    public let serverUrl: String
    public let username: String
    public let token: String

    public static func parse(from string: String) -> DevicePayload? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DevicePayload.self, from: data)
    }
}
