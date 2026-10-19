import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct DropZoneView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var clipboardUploader = ClipboardUploader.shared

    @State private var isTargeted: Bool = false
    @State private var selectedDestination: String = "/"
    @State private var showCustomFolderInput: Bool = false
    @State private var customFolderText: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // Destination Folder Selector
            HStack(spacing: 8) {
                Label("Destination:", systemImage: "folder.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedDestination) {
                    ForEach(appState.remoteFolders, id: \.self) { folder in
                        Text(folder == "/" ? "Cloud Root (/)" : folder).tag(folder)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)

                Spacer()
            }
            .padding(.horizontal, 14)

            // Drag and Drop Target Box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.blue : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.blue.opacity(0.12) : Color.primary.opacity(0.03))
                    )

                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(
                            isTargeted
                                ? LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.secondary, .secondary.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .scaleEffect(isTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: isTargeted)

                    Text(isTargeted ? "Drop files to upload now" : "Drag & Drop files or folders here")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isTargeted ? .blue : .primary)

                    Text("or click below to browse from your Mac")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button(action: openFilePicker) {
                            Label("Browse Files", systemImage: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: uploadClipboard) {
                            HStack(spacing: 4) {
                                if clipboardUploader.isUploading {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "doc.on.clipboard")
                                }
                                Text("Upload Clipboard")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(clipboardUploader.isUploading)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 22)
            }
            .padding(.horizontal, 14)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDroppedProviders(providers)
                return true
            }

            // Clipboard Status Message
            if let msg = clipboardUploader.statusMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(msg.contains("failed") ? .red : .green)
                    .padding(.horizontal, 14)
            }

            // Transfers / Recent Activity Header
            if !appState.recentTransfers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Recent Transfers")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)

                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(appState.recentTransfers.prefix(5)) { item in
                                TransferRow(item: item)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .frame(maxHeight: 120)
                }
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        var urlsToUpload: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                defer { group.leave() }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urlsToUpload.append(url)
                } else if let url = item as? URL {
                    urlsToUpload.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            Task {
                await appState.uploadFiles(urlsToUpload, destination: selectedDestination)
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files or folders to upload to ClyoCloud"

        if panel.runModal() == .OK {
            let selectedURLs = panel.urls
            Task {
                await appState.uploadFiles(selectedURLs, destination: selectedDestination)
            }
        }
    }

    private func uploadClipboard() {
        Task {
            let dest = selectedDestination == "/" ? "" : selectedDestination
            _ = await clipboardUploader.uploadClipboardImage(destinationPath: dest)
            await appState.refreshData()
        }
    }
}

struct TransferRow: View {
    let item: TransferItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.size > 0 {
                    Text(item.formattedSize)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            switch item.status {
            case .pending:
                Text("Queued")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            case .inProgress(let progress):
                ProgressView(value: progress)
                    .frame(width: 50)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
            case .failed(let err):
                Text(err)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
    }

    private var iconName: String {
        switch item.type {
        case .upload, .clipboard: return "arrow.up.circle"
        case .download: return "arrow.down.circle"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .completed: return .green
        case .failed: return .red
        default: return .blue
        }
    }
}
