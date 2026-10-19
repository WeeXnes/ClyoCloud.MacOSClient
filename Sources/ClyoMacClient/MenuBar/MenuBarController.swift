import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?

    private var dragOverlayView: MenuBarDragView?

    public override init() {
        super.init()
    }

    public func setup() {
        // 1. Create NSStatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusIcon(isSyncing: false)
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Setup drag-and-drop destination on the menu bar button
            let dragView = MenuBarDragView(frame: button.bounds)
            dragView.autoresizingMask = [.width, .height]
            dragView.onDropFiles = { urls in
                Task { @MainActor in
                    await AppState.shared.uploadFiles(urls, destination: "/")
                    self.showPopover()
                }
            }
            button.addSubview(dragView)
            self.dragOverlayView = dragView
        }

        // 2. Create NSPopover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 490)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverRootView())
        popover.delegate = self

        // 3. Monitor sync state changes to animate/update menu bar icon
        observeSyncState()
    }

    private func updateStatusIcon(isSyncing: Bool) {
        guard let button = statusItem.button else { return }

        let iconName = isSyncing ? "arrow.triangle.2.circlepath" : "cloud.fill"
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ClyoCloud") {
            image.isTemplate = true
            button.image = image
        }
    }

    private func observeSyncState() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                let isSyncing = SyncEngine.shared.isSyncing
                self?.updateStatusIcon(isSyncing: isSyncing)
            }
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    public func togglePopover() {
        if popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    public func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hidePopover() {
        popover.performClose(nil)
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let appState = AppState.shared
        let statusTitle = appState.isAuthenticated ? "ClyoCloud (\(appState.currentUser))" : "ClyoCloud (Not Connected)"
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Open ClyoCloud Web", action: #selector(openWeb), keyEquivalent: "w"))
        menu.addItem(NSMenuItem(title: "Sync All Folders Now", action: #selector(triggerSyncNow), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Upload Clipboard Image", action: #selector(triggerClipboardUpload), keyEquivalent: "v"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit ClyoCloud", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    @objc private func openWeb() {
        if let url = URL(string: SettingsManager.shared.serverUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func triggerSyncNow() {
        Task { @MainActor in
            await SyncEngine.shared.syncAll()
        }
    }

    @objc private func triggerClipboardUpload() {
        Task { @MainActor in
            _ = await ClipboardUploader.shared.uploadClipboardImage()
        }
    }

    @objc private func openPreferences() {
        AppState.shared.selectedTab = .settings
        showPopover()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// Drag-and-drop destination view for Menu Bar Icon
final class MenuBarDragView: NSView {
    var onDropFiles: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !items.isEmpty else {
            return false
        }
        onDropFiles?(items)
        return true
    }
}
