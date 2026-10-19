import SwiftUI
import AppKit

public struct PopoverRootView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var syncEngine = SyncEngine.shared
    @ObservedObject var settings = SettingsManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top App Bar
            HStack(spacing: 8) {
                // Cloud Icon & Brand
                Image(systemName: "cloud.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 15))

                Text("ClyoCloud")
                    .font(.system(size: 13, weight: .bold))

                // Status Indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusIndicatorColor)
                        .frame(width: 6, height: 6)

                    if syncEngine.isSyncing {
                        Text("Syncing")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.blue)
                    } else if appState.isAuthenticated {
                        Text("Connected")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Disconnected")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(10)

                Spacer()

                if appState.isAuthenticated {
                    // Refresh Button
                    Button(action: {
                        Task { await appState.refreshData() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .rotationEffect(.degrees(appState.isRefreshing ? 360 : 0))
                            .animation(appState.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isRefreshing)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Data")
                }

                // Quit Button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit ClyoCloud")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if !appState.isAuthenticated {
                LoginView()
            } else {
                // Storage Bar
                if let stats = appState.serverStats {
                    HStack(spacing: 8) {
                        ProgressView(value: stats.usedPercentage)
                            .tint(stats.usedPercentage > 0.9 ? .red : .blue)
                            .scaleEffect(y: 0.7)

                        Text("\(stats.formattedUsed) / \(stats.formattedTotal)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.02))

                    Divider()
                }

                // Tab Selector
                HStack(spacing: 2) {
                    ForEach(ActiveTab.allCases) { tab in
                        Button(action: {
                            appState.selectedTab = tab
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: tab.systemIcon)
                                    .font(.system(size: 13))
                                Text(tab.rawValue)
                                    .font(.system(size: 9, weight: appState.selectedTab == tab ? .bold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundColor(appState.selectedTab == tab ? .blue : .secondary)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider()

                // Content Views
                Group {
                    switch appState.selectedTab {
                    case .upload:
                        DropZoneView()
                    case .wallpapers:
                        WallpaperGridView()
                    case .sync:
                        SyncedFoldersView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 380, height: 490)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    private var statusIndicatorColor: Color {
        if syncEngine.isSyncing { return .blue }
        if appState.isAuthenticated { return .green }
        return .red
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
