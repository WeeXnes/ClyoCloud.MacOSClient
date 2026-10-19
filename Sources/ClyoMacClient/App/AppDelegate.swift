import Foundation
import AppKit
import UserNotifications

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalEventMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory app (No Dock icon, menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize core state & settings
        _ = SettingsManager.shared
        _ = AppState.shared

        // Initialize Menu Bar & Popover
        MenuBarController.shared.setup()

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Setup global hotkey for clipboard upload (Option + Command + U)
        setupGlobalHotkey()
    }

    private func setupGlobalHotkey() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Check for Option + Command + U (Key code 32 = 'u')
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .option] && event.keyCode == 32 {
                Task { @MainActor in
                    _ = await ClipboardUploader.shared.uploadClipboardImage()
                }
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
