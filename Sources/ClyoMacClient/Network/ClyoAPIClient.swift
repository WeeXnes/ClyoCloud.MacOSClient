import Foundation
import AppKit

public enum ClyoAPIError: LocalizedError {
    case invalidURL
    case unauthorized
    case requiresTwoFactor(tempToken: String)
    case serverError(statusCode: Int, message: String)
    case networkError(Error)
    case decodingError(Error)
    case noData

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .unauthorized:
            return "Unauthorized. Please check your credentials or token."
        case .requiresTwoFactor:
            return "Two-factor authentication required"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .networkError(let err):
            return "Network connection error: \(err.localizedDescription)"
        case .decodingError(let err):
            return "Response decoding error: \(err.localizedDescription)"
        case .noData:
            return "No data received from server"
        }
    }
}

public final class ClyoAPIClient {
    public static let shared = ClyoAPIClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        self.session = URLSession(configuration: config)
    }

    private var deviceModelName: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let hw = String(cString: model)
        if !hw.isEmpty {
            return "Mac (\(hw))"
        }
        return "macOS Device"
    }

    private func makeURL(endpoint: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        var base = SettingsManager.shared.serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") {
            base.removeLast()
        }
        guard var components = URLComponents(string: base + endpoint) else {
            throw ClyoAPIError.invalidURL
        }
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw ClyoAPIError.invalidURL
        }
        return url
    }

    private func createRequest(url: URL, method: String = "GET", token: String? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(deviceModelName, forHTTPHeaderField: "X-Device-Model")
        req.setValue("ClyoMacClient/1.0", forHTTPHeaderField: "User-Agent")

        let authToken = token ?? KeychainHelper.shared.readToken(for: SettingsManager.shared.username)
        if let authToken = authToken, !authToken.isEmpty {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // MARK: - Authentication

    public func login(username: String, password: String) async throws -> (token: String?, requires2fa: Bool, tempToken: String?) {
        let url = try makeURL(endpoint: "/api/login")
        var req = createRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["username": username, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClyoAPIError.serverError(statusCode: 500, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let req2fa = json["requires2fa"] as? Bool, req2fa, let temp = json["tempToken"] as? String {
                    return (nil, true, temp)
                }
                if let token = json["token"] as? String {
                    return (token, false, nil)
                }
            }
        }

        let msg = extractErrorMessage(data: data) ?? "Login failed"
        throw ClyoAPIError.serverError(statusCode: httpResponse.statusCode, message: msg)
    }

    public func verify2FA(tempToken: String, code: String) async throws -> String {
        let url = try makeURL(endpoint: "/api/2fa/verify-login")
        var req = createRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["tempToken": tempToken, "token": code]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClyoAPIError.serverError(statusCode: 500, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                return token
            }
        }

        let msg = extractErrorMessage(data: data) ?? "Invalid 2FA code"
        throw ClyoAPIError.serverError(statusCode: httpResponse.statusCode, message: msg)
    }

    public func verifyToken(token: String, username: String) async throws -> Bool {
        let url = try makeURL(endpoint: "/api/verify")
        let req = createRequest(url: url, method: "GET", token: token)
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            return http.statusCode == 200
        }
        return false
    }

    // MARK: - Files & Directories

    public func fetchFiles(path: String = "") async throws -> [ClyoFile] {
        var queryItems: [URLQueryItem] = []
        if !path.isEmpty {
            queryItems.append(URLQueryItem(name: "path", value: path))
        }
        let url = try makeURL(endpoint: "/api/files", queryItems: queryItems)
        let req = createRequest(url: url)

        let (data, response) = try await session.data(for: req)
        try checkResponse(response, data: data)

        do {
            return try JSONDecoder().decode([ClyoFile].self, from: data)
        } catch {
            throw ClyoAPIError.decodingError(error)
        }
    }

    public func fetchWallpapers() async throws -> [ClyoFile] {
        let url = try makeURL(endpoint: "/api/wallpapers")
        let req = createRequest(url: url)

        let (data, response) = try await session.data(for: req)
        try checkResponse(response, data: data)

        do {
            return try JSONDecoder().decode([ClyoFile].self, from: data)
        } catch {
            throw ClyoAPIError.decodingError(error)
        }
    }

    public func fetchStats() async throws -> ServerStats {
        let url = try makeURL(endpoint: "/api/stats")
        let req = createRequest(url: url)

        let (data, response) = try await session.data(for: req)
        try checkResponse(response, data: data)

        do {
            return try JSONDecoder().decode(ServerStats.self, from: data)
        } catch {
            throw ClyoAPIError.decodingError(error)
        }
    }

    public func createFolder(folderName: String, path: String) async throws {
        let url = try makeURL(endpoint: "/api/folder")
        var req = createRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["folderName": folderName, "path": path]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        try checkResponse(response, data: data)
    }

    public func renameFile(oldPath: String, newName: String) async throws {
        let url = try makeURL(endpoint: "/api/rename")
        var req = createRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["oldPath": oldPath, "newName": newName]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        try checkResponse(response, data: data)
    }

    public func deleteFile(path: String, permanent: Bool = false) async throws {
        let url = try makeURL(endpoint: "/api/files")
        var req = createRequest(url: url, method: "DELETE")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["path": path, "permanent": permanent]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        try checkResponse(response, data: data)
    }

    // MARK: - Image & Thumbnail Caching

    private let thumbnailCache = NSCache<NSString, NSImage>()

    public func fetchThumbnailImage(for path: String) async -> NSImage? {
        let cleaned = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cacheKey = cleaned as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        guard let encodedPath = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        // 1. Try /thumbnail first (authenticated)
        if let thumbURL = try? makeURL(endpoint: "/thumbnail/\(encodedPath)") {
            let req = createRequest(url: thumbURL)
            if let (data, response) = try? await session.data(for: req),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let img = NSImage(data: data) {
                thumbnailCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        // 2. Fallback to /file if thumbnail hasn't been generated yet
        if let fileURL = try? makeURL(endpoint: "/file/\(encodedPath)") {
            let req = createRequest(url: fileURL)
            if let (data, response) = try? await session.data(for: req),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let img = NSImage(data: data) {
                thumbnailCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        return nil
    }

    // MARK: - Upload (Multipart/form-data)

    public func upload(
        files: [URL],
        toPath remotePath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let url = try makeURL(endpoint: "/api/upload")
        let boundary = "Boundary-\(UUID().uuidString)"

        var req = createRequest(url: url, method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Path field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(remotePath)\r\n".data(using: .utf8)!)

        // File fields
        for fileURL in files {
            let filename = fileURL.lastPathComponent
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Stream body with progress
        progressHandler?(0.1)
        let (data, response) = try await session.upload(for: req, from: body)
        progressHandler?(1.0)

        try checkResponse(response, data: data)
    }

    public func uploadData(
        data: Data,
        filename: String,
        toPath remotePath: String
    ) async throws {
        let url = try makeURL(endpoint: "/api/upload")
        let boundary = "Boundary-\(UUID().uuidString)"

        var req = createRequest(url: url, method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(remotePath)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (respData, response) = try await session.upload(for: req, from: body)
        try checkResponse(response, data: respData)
    }

    // MARK: - Download

    public func downloadFile(remotePath: String, to destinationURL: URL) async throws {
        let cleanedPath = remotePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encodedPath = cleanedPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw ClyoAPIError.invalidURL
        }

        let url = try makeURL(endpoint: "/file/\(encodedPath)")
        let req = createRequest(url: url)

        let (tempURL, response) = try await session.download(for: req)
        try checkResponse(response, data: nil)

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        let dir = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try fileManager.moveItem(at: tempURL, to: destinationURL)
    }

    public func getThumbnailURL(for path: String) -> URL? {
        let cleaned = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return try? makeURL(endpoint: "/thumbnail/\(encoded)")
    }

    public func getFileURL(for path: String) -> URL? {
        let cleaned = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return try? makeURL(endpoint: "/file/\(encoded)")
    }

    // MARK: - Helpers

    private func checkResponse(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClyoAPIError.serverError(statusCode: 500, message: "Invalid HTTP response")
        }
        if http.statusCode == 401 {
            throw ClyoAPIError.unauthorized
        }
        if http.statusCode < 200 || http.statusCode >= 300 {
            let msg = data.flatMap { extractErrorMessage(data: $0) } ?? "HTTP \(http.statusCode)"
            throw ClyoAPIError.serverError(statusCode: http.statusCode, message: msg)
        }
    }

    private func extractErrorMessage(data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = json["statusMessage"] as? String { return msg }
            if let msg = json["message"] as? String { return msg }
            if let msg = json["error"] as? String { return msg }
        }
        return String(data: data, encoding: .utf8)
    }
}
