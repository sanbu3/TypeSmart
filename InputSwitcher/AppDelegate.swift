import Cocoa
import InputMethodKit
import SwiftUI // Keep for NSHostingController if used, or other SwiftUI elements
import ServiceManagement // For AXIsProcessTrustedWithOptions, kAXTrustedCheckOptionPrompt
// 移除错误的导入语句

class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer?
    // var lastActiveAppPath: String? // No longer seems to be used, consider removing if confirmed
    static var statusItem: NSStatusItem?
    
    // Access AppState through its singleton
    let appState = AppState.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching.")
        checkAccessibilityPermissions()
        appState.discoverApplications() // Use the appState instance
        setupStatusItem()

        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkActiveApplication), userInfo: nil, repeats: true)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeAppDidChange), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        
        appState.loadLaunchAtLoginState() // Use the appState instance
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let item = AppDelegate.statusItem {
            NSStatusBar.system.removeStatusItem(item)
            AppDelegate.statusItem = nil
        }
    }

    @objc func activeAppDidChange(notification: NSNotification) {
        guard let newApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = newApp.bundleIdentifier else {
            return
        }
        handleAppSwitch(to: bundleID)
        appState.lastActiveAppIdentifier = bundleID // Use the appState instance
    }

    @objc func checkActiveApplication() {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = activeApp.bundleIdentifier else {
            return
        }
        
        if bundleID != appState.lastActiveAppIdentifier { // Use the appState instance
            handleAppSwitch(to: bundleID)
            appState.lastActiveAppIdentifier = bundleID // Use the appState instance
        }
    }

    func handleAppSwitch(to appIdentifier: String) {
        print("[AppDelegate] handleAppSwitch: 应用切换到 \(appIdentifier)")
        
        
        // 检查是否有匹配的规则
        if let targetInputSourceID = appState.appInputSourceMap[appIdentifier] {
            print("[AppDelegate] handleAppSwitch: 找到匹配规则，切换到输入法 ID: \(targetInputSourceID)")
            let success = InputSourceManager.shared.switchToInputSource(withID: targetInputSourceID)
            if success {
                print("[AppDelegate] handleAppSwitch: 成功切换到输入法 ID: \(targetInputSourceID)")
            } else {
                print("[AppDelegate] handleAppSwitch: 切换到输入法 ID: \(targetInputSourceID) 失败")
            }
        } else {
            print("[AppDelegate] handleAppSwitch: 未找到匹配规则")
        }
    }

    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("Accessibility permissions are NOT granted. Please grant them in System Settings > Privacy & Security > Accessibility.")
        } else {
            print("Accessibility permissions are granted.")
        }
    }

    func setupStatusItem() {
        AppDelegate.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = AppDelegate.statusItem?.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "Input Switcher Settings")
            } else {
                button.title = "切换"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开设置", action: #selector(openSettingsWindow), keyEquivalent: "S"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "刷新应用列表", action: #selector(refreshAppList), keyEquivalent: "R"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        AppDelegate.statusItem?.menu = menu
        print("Status item setup complete.")
    }

    @objc func openSettingsWindow() {
        print("Attempting to open settings window.")
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            // Fallback for older macOS versions to bring the app to front and hope the main window is the settings.
            // This might need to be more robust if you have multiple windows.
            NSApp.activate(ignoringOtherApps: true)
            // Attempt to find and show the main window if it's not already visible.
            // This assumes the ContentView is in a WindowGroup which is the main window.
            // If you have a dedicated settings window, you'd need a way to reference and show it.
            if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<ContentView> }) {
                 window.makeKeyAndOrderFront(self)
                 print("Found and opened settings window for older macOS.")
            } else {
                print("Could not find existing settings window to open for older macOS. App activated.")
                // As a last resort, if no specific window is found, opening a new one might be an option,
                // but this depends on how your app is structured and if WindowGroup handles this gracefully.
                // For now, just activating the app is the safest fallback.
            }
        }
    }
    
    @objc func refreshAppList() {
        print("Refreshing application list via menu bar.")
        appState.discoverApplications() // Use the appState instance
    }
}
