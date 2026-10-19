import Foundation
import AppKit
import UserNotifications

public final class ClipboardUploader: ObservableObject {
    public static let shared = ClipboardUploader()

    @Published public var isUploading: Bool = false
    @Published public var statusMessage: String? = nil

    private init() {}

    @MainActor
    public func uploadClipboardImage(destinationPath: String = "") async -> Bool {
        isUploading = true
        statusMessage = "Reading clipboard..."
        defer { isUploading = false }

        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard) else {
            statusMessage = "No image found on clipboard"
            notify(title: "ClyoCloud", body: "No image on clipboard. Copy an image or take a screenshot first.")
            return false
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            statusMessage = "Failed to convert image to PNG"
            return false
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "Screenshot_\(formatter.string(from: Date())).png"

        statusMessage = "Uploading \(filename)..."

        do {
            try await ClyoAPIClient.shared.uploadData(data: pngData, filename: filename, toPath: destinationPath)

            let fullRemotePath = destinationPath.isEmpty ? filename : "\(destinationPath)/\(filename)"
            let fileURL = ClyoAPIClient.shared.getFileURL(for: fullRemotePath)?.absoluteString ?? fullRemotePath

            // Copy file URL to pasteboard
            pasteboard.clearContents()
            pasteboard.setString(fileURL, forType: .string)

            statusMessage = "Uploaded & link copied to clipboard!"
            notify(title: "Upload Succeeded", body: "Uploaded \(filename) to ClyoCloud. Link copied to clipboard.")
            return true
        } catch {
            statusMessage = "Upload failed: \(error.localizedDescription)"
            notify(title: "Upload Failed", body: error.localizedDescription)
            return false
        }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
