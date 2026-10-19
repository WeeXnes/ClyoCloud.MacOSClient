import SwiftUI
import AppKit

public struct SyncedFoldersView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var syncEngine = SyncEngine.shared
    @State private var showingAddSheet: Bool = false
    @State private var newLocalPath: String = ""
    @State private var newRemotePath: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 10) {
            // Header with Sync Now
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Synced Folders")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(syncEngine.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    Task { await syncEngine.syncAll() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(syncEngine.isSyncing ? 360 : 0))
                            .animation(syncEngine.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncEngine.isSyncing)
                        Text(syncEngine.isSyncing ? "Syncing..." : "Sync Now")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(syncEngine.isSyncing)

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            // Synced Folders List
            if settings.syncFolderPairs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .foregroundColor(.secondary)

                    Text("No synced folders")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("Add a local Mac folder to automatically keep it synchronized two-way with your ClyoCloud.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button("Add Synced Folder") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(settings.syncFolderPairs) { pair in
                            SyncFolderRow(pair: pair)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSyncFolderSheet(isPresented: $showingAddSheet)
        }
    }
}

struct SyncFolderRow: View {
    let pair: SyncFolderPair
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.localFolderName)
                        .font(.system(size: 12, weight: .semibold))
                    Text(pair.localPath)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Status Badge
                Text(pair.statusDescription)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)

                // Delete Button
                Button(action: {
                    settings.removeSyncPair(id: pair.id)
                    SyncEngine.shared.restartWatcher()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Image(systemName: "arrow.right.arrow.left")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("Remote: \(pair.remoteFolderName)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if let date = pair.lastSyncTime {
                    Text("Synced \(timeAgo(from: date))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        if pair.statusDescription.contains("Syncing") { return .blue }
        if pair.statusDescription.contains("In Sync") || pair.statusDescription.contains("Ready") { return .green }
        return .orange
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AddSyncFolderSheet: View {
    @Binding var isPresented: Bool
    @State private var localPath: String = ""
    @State private var remotePath: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            Text("Add Synced Folder")
                .font(.headline)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 6) {
                Text("Local Folder on Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("/Users/.../Folder", text: $localPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))

                    Button("Browse...") {
                        selectLocalFolder()
                    }
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Cloud Folder Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g. MacSync or leave blank for root", text: $remotePath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save & Start Syncing") {
                    savePair()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(localPath.isEmpty)
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(width: 380)
    }

    private func selectLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select local folder to synchronize with ClyoCloud"

        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
            if remotePath.isEmpty {
                remotePath = url.lastPathComponent
            }
        }
    }

    private func savePair() {
        guard !localPath.isEmpty else {
            errorMessage = "Please select a local folder"
            return
        }
        SettingsManager.shared.addSyncPair(localPath: localPath, remotePath: remotePath)
        SyncEngine.shared.restartWatcher()
        Task {
            await SyncEngine.shared.syncAll()
        }
        isPresented = false
    }
}
