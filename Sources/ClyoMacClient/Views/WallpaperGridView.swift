import SwiftUI

public struct WallpaperGridView: View {
    @ObservedObject var wallpaperManager = WallpaperManager.shared
    @State private var successWallpaperName: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Label("Cloud Wallpapers (\(wallpaperManager.wallpapers.count))", systemImage: "photo.stack")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    Task { await wallpaperManager.loadWallpapers() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(wallpaperManager.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            if wallpaperManager.isLoading && wallpaperManager.wallpapers.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading cloud wallpapers...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else if wallpaperManager.wallpapers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.secondary)

                    Text("No wallpapers found")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("Star or flag images as 'Wallpaper' in ClyoCloud to manage and set them from here.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 30)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(wallpaperManager.wallpapers) { file in
                            WallpaperThumbnailCard(
                                file: file,
                                isSetting: wallpaperManager.currentSettingWallpaperName == file.name,
                                isSuccess: successWallpaperName == file.name
                            ) {
                                Task {
                                    let ok = await wallpaperManager.setAsDesktopWallpaper(file: file)
                                    if ok {
                                        successWallpaperName = file.name
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                            if successWallpaperName == file.name {
                                                successWallpaperName = nil
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }

            if let err = wallpaperManager.errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
            }
        }
        .onAppear {
            if wallpaperManager.wallpapers.isEmpty {
                Task { await wallpaperManager.loadWallpapers() }
            }
        }
    }
}

struct WallpaperThumbnailCard: View {
    let file: ClyoFile
    let isSetting: Bool
    let isSuccess: Bool
    let onSet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                // Thumbnail
                if let thumbURL = ClyoAPIClient.shared.getThumbnailURL(for: file.name) {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .overlay(ProgressView().scaleEffect(0.5))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 85)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 85)
                        .cornerRadius(8)
                }

                // Status or Action Button
                if isSetting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(4)
                } else if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(4)
                }
            }

            // Filename
            Text(file.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            // 1-Click Set Button
            Button(action: onSet) {
                HStack(spacing: 3) {
                    Image(systemName: isSuccess ? "checkmark" : "display")
                        .font(.system(size: 9))
                    Text(isSuccess ? "Applied!" : "Set as Desktop")
                        .font(.system(size: 9, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(isSuccess ? .green : .blue)
            .controlSize(.mini)
            .disabled(isSetting)
        }
        .padding(6)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }
}
