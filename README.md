# 🌌 ClyoCloud for macOS (Native Menu Bar Client)

A lightweight, native macOS companion application for **ClyoCloud**, living directly in your top menu bar with native macOS integration, real-time two-way folder synchronization, drag-and-drop cloud uploads, cloud wallpaper management, and instant clipboard uploader.

---

## 🚀 Key Features

* **⚡ Native Top Menu Bar Integration**:
  * Clean monochrome glyph matching macOS status icons (Battery, Control Center, Media Player).
  * Dynamic status indicator (idle, animated rotating sync icon during active transfers, offline indicator).
  * Left-click opens the translucent frosted-glass popover; right-click opens a quick utility context menu.
  * Direct **Drag-and-Drop onto the menu bar icon** from Finder to trigger an instant upload.

* **📂 Drag-and-Drop Upload Zone**:
  * Glassmorphic drag target in the popover accepting multiple files or folders from Finder.
  * Destination folder picker (upload to cloud root `/` or any specific remote folder).
  * Real-time transfer progress bars and recent activity tracking.

* **🖼️ Cloud Desktop Wallpaper Gallery (Submenu)**:
  * Dedicated scrollable grid view fetching your cloud wallpapers (`/api/wallpapers`).
  * Instant 1-click **"Set as Desktop Wallpaper"** action that applies the image to your Mac screens natively via `NSWorkspace`.

* **🔄 Real-Time Two-Way Folder Synchronization**:
  * Kernel-level **macOS `FSEvents`** monitoring: detects local file additions, modifications, and deletions with zero CPU overhead.
  * Two-way differential sync comparing remote files (`/api/files`) against local directories.
  * Automatic filtering of macOS metadata (`.DS_Store`, `.localized`, temporary downloads, `.cloudinfo`).

* **📸 Screenshot & Clipboard Uploader**:
  * Click **"Upload Clipboard"** or press **`⌥ + ⌘ + U`** (Option + Command + U) anywhere on your Mac to grab the image on your clipboard, upload it directly to ClyoCloud, and automatically copy the share link.

* **🔑 Dual Authentication**:
  * **Quick Device Token / QR Payload**: Paste a device token or QR JSON payload from ClyoCloud settings (registered in `devices.json` with a 365-day session). Automatically reports device model `Mac (...)` to the server.
  * **Standard Credentials**: Username and Password with support for TOTP 2FA codes and recovery scratch keys.
  * Tokens stored securely in the **macOS Keychain**.

* **🚀 Launch at Login**:
  * Integrated with macOS 13+ `SMAppService` to automatically start ClyoCloud silently on system boot.

---

## 🛠 Building & Running

### Prerequisites
* macOS 13+ (Ventura, Sonoma, or later)
* Apple Command Line Tools (`swiftc`, `make`)

### Build & Run
Run from the project root:
```bash
# Build standalone ClyoCloud.app
make app

# Launch ClyoCloud.app
make run
```

### Install to Applications
```bash
make install
```
This moves `ClyoCloud.app` to `/Applications/ClyoCloud.app` for permanent access.

---

## 📁 Project Architecture

```
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
