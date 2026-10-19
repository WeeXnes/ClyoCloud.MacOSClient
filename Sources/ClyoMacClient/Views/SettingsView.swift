import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settings = SettingsManager.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Account Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connected Account")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.currentUser.isEmpty ? "Connected User" : appState.currentUser)
                                .font(.system(size: 13, weight: .semibold))
                            Text(settings.serverUrl)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button(action: openWebDashboard) {
                            Image(systemName: "safari")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .help("Open Web Dashboard")
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }

                // System & Server Metrics
                if let stats = appState.serverStats {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Resource Metrics")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            // Storage Bar
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Storage Quota")
                                        .font(.caption2)
                                    Spacer()
                                    Text("\(stats.formattedUsed) / \(stats.formattedTotal)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                ProgressView(value: stats.usedPercentage)
                                    .tint(stats.usedPercentage > 0.9 ? .red : .blue)
                            }

                            Divider()

                            // CPU & RAM
                            HStack(spacing: 16) {
                                if let cpu = stats.cpu, let load = cpu.load {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Server CPU Load")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f%%", load))
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }

                                if let ram = stats.ram {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Server RAM Usage")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f%%", ram.usedPercentage * 100))
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                    }
                }

                // App Preferences
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Toggle("Launch at System Login", isOn: $settings.launchAtLogin)
                            .toggleStyle(SwitchToggleStyle())
                            .font(.system(size: 12))

                        Divider()

                        HStack {
                            Text("Registered Device Model")
                                .font(.system(size: 11))
                            Spacer()
                            Text("Mac (macOS 13+)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }

                // Actions
                VStack(spacing: 8) {
                    Button(action: openWebDashboard) {
                        Label("Open ClyoCloud in Browser", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        appState.logout()
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 4)

                // Version Info
                Text("ClyoCloud for macOS • Version 1.0.0")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func openWebDashboard() {
        if let url = URL(string: settings.serverUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
