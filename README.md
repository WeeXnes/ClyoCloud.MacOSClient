# ClyoCloud for macOS

Native macOS menu bar client for [ClyoCloud](https://code.weexnes.dev/ClyoCloud): two-way folder sync, drag-and-drop uploads, cloud wallpapers and a clipboard uploader.

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-000000?style=flat-square&labelColor=1f1f1f)](#requirements)
[![Stack](https://img.shields.io/badge/stack-Swift-000000?style=flat-square&labelColor=1f1f1f)](#build-from-source)

A lightweight companion app that lives in your top menu bar, with native macOS integration, real-time two-way folder
synchronization, drag-and-drop cloud uploads, cloud wallpaper management, and an instant clipboard uploader.

## Features

- **Native menu bar integration:**
  - Clean monochrome glyph matching the macOS status icons (Battery, Control Center, Media Player).
  - Dynamic status indicator (idle, animated rotating sync icon during active transfers, offline indicator).
  - Left-click opens the translucent frosted-glass popover; right-click opens a quick utility context menu.
  - **Drag and drop onto the menu bar icon** from Finder to start an upload immediately.
- **Drag-and-drop upload zone:**
  - Glassmorphic drop target in the popover that accepts multiple files or folders from Finder.
  - Destination folder picker (upload to the cloud root `/` or any remote folder).
  - Real-time transfer progress bars and recent activity tracking.
- **Cloud desktop wallpaper gallery (submenu):**
  - Scrollable grid view of your cloud wallpapers (`/api/wallpapers`).
  - One-click **"Set as Desktop Wallpaper"** applies the image to your Mac screens natively via `NSWorkspace`.
- **Real-time two-way folder synchronization:**
  - Kernel-level **macOS `FSEvents`** monitoring detects local file additions, modifications and deletions with no CPU overhead.
  - Two-way differential sync comparing remote files (`/api/files`) against local directories.
  - Automatic filtering of macOS metadata (`.DS_Store`, `.localized`, temporary downloads, `.cloudinfo`).
- **Screenshot and clipboard uploader:**
  - Click **"Upload Clipboard"** or press **`⌥ + ⌘ + U`** (Option + Command + U) anywhere on your Mac to grab the image on your clipboard, upload it to ClyoCloud, and copy the share link.
- **Dual authentication:**
  - **Quick device token / QR payload:** paste a device token or QR JSON payload from ClyoCloud settings (registered in `devices.json` with a 365-day session). Reports the device model `Mac (...)` to the server.
  - **Standard credentials:** username and password, with support for TOTP 2FA codes and recovery scratch keys.
  - Tokens are stored in the **macOS Keychain**.
- **Launch at login:**
  - Uses the macOS 13+ `SMAppService` to start ClyoCloud silently on system boot.

## Requirements

- macOS 13+ (Ventura, Sonoma, or later)
- Apple Command Line Tools (`swiftc`, `make`)

## Install

```bash
make install
```

This moves `ClyoCloud.app` to `/Applications/ClyoCloud.app` for permanent access.

## Build from source

Run from the project root:

```bash
# Build standalone ClyoCloud.app
make app

# Launch ClyoCloud.app
make run
```

## Project structure

```text
ClyoMacClient/
├── Makefile                          # Build, run, and install commands
├── scripts/
│   └── build_app.sh                  # Compiles Swift sources and bundles ClyoCloud.app
├── Resources/
│   └── Info.plist                    # LSUIElement agent configuration & permissions
└── Sources/
    └── ClyoMacClient/
        ├── main.swift                # App entry point
        ├── App/
        │   ├── AppDelegate.swift     # App lifecycle, notifications, global hotkeys
        │   └── AppState.swift        # Central reactive state (auth, transfers, folders)
        ├── MenuBar/
        │   └── MenuBarController.swift # NSStatusItem, NSPopover, menu bar drag-and-drop
        ├── Views/
        │   ├── PopoverRootView.swift # Main window with tabs (Upload, Wallpapers, Sync, Settings)
        │   ├── DropZoneView.swift    # Drag-and-drop uploader & transfer progress
        │   ├── WallpaperGridView.swift # Visual cloud wallpaper picker & desktop setter
        │   ├── SyncedFoldersView.swift # Local <-> Cloud synced folder pair manager
        │   ├── SettingsView.swift    # Account status, server CPU/RAM meters, launch at login
        │   └── LoginView.swift       # Dual authentication UI (QR token / credentials + 2FA)
        ├── Sync/
        │   ├── SyncEngine.swift      # Two-way differential synchronization engine
        │   └── FSEventWatcher.swift  # macOS FSEvents kernel filesystem monitor
        ├── Network/
        │   └── ClyoAPIClient.swift   # REST API client (multipart upload, download, stats)
        ├── Storage/
        │   ├── KeychainHelper.swift  # macOS Keychain token storage
        │   └── SettingsManager.swift # UserDefaults preferences and Launch at Login
        ├── Wallpaper/
        │   └── WallpaperManager.swift # Fetches cloud wallpapers and applies via NSWorkspace
        ├── Clipboard/
        │   └── ClipboardUploader.swift # Grabs clipboard images and copies share link
        └── Models/
            ├── ClyoFile.swift        # File metadata, tags, and types
            ├── ServerStats.swift     # CPU, RAM, and Disk storage metrics
            ├── SyncModels.swift      # Sync folder pair and state models
            ├── TransferItem.swift    # Upload/download progress item
            └── DevicePayload.swift   # QR login payload parser
```

## License

No license has been chosen yet.
