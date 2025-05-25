import Cocoa
import InputMethodKit
import SwiftUI
import ServiceManagement
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer?
    static var statusItem: NSStatusItem?
    
    // 防止递归切换的标志
    private var isInternalInputSourceChange = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching.")
        
        // Auto-check permissions if enabled
        if AppState.shared.autoCheckPermissions {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                let _ = AXIsProcessTrustedWithOptions(options)
                // 日志可选
            }
        }
        
        // Apply dock icon visibility setting
        AppState.shared.updateDockIconVisibility()
        
        AppState.shared.discoverApplications()
        setupStatusItem()
        startTimer()
        
        // Listen for status bar visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusBarVisibilityChanged),
            name: .statusBarVisibilityChanged,
            object: nil
        )
        
        AppState.shared.loadLaunchAtLoginState()
        
        // 立即检查当前活动应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkActiveApplication()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        if let item = AppDelegate.statusItem {
            NSStatusBar.system.removeStatusItem(item)
            AppDelegate.statusItem = nil
        }
    }
    
    func startTimer() {
        // 设置定时器监听活动应用 - 更频繁的检查以确保及时响应
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(checkActiveApplication), userInfo: nil, repeats: true)
        
        // 监听应用激活通知
        NSWorkspace.shared.notificationCenter.addObserver(
            self, 
            selector: #selector(activeAppDidChange), 
            name: NSWorkspace.didActivateApplicationNotification, 
            object: nil
        )
        
        // 添加应用停用通知监听，用于更准确的应用切换检测
        NSWorkspace.shared.notificationCenter.addObserver(
            self, 
            selector: #selector(activeAppDidChange), 
            name: NSWorkspace.didDeactivateApplicationNotification, 
            object: nil
        )
        
        // 监听输入法变化通知
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    @objc func activeAppDidChange(notification: NSNotification) {
        guard let newApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = newApp.bundleIdentifier else {
            return
        }
        handleAppSwitch(to: bundleID)
        AppState.shared.lastActiveAppIdentifier = bundleID
    }
    
    @objc func inputSourceDidChange() {
        // 如果是程序内部的输入法切换，则忽略这个通知
        if isInternalInputSourceChange {
            print("[AppDelegate] 忽略程序内部的输入法变化通知")
            return
        }
        
        print("[AppDelegate] 外部输入法发生变化")
        // 这里可以添加额外的逻辑来处理外部输入法变化
        // 例如记录输入法切换统计等
    }

    @objc func checkActiveApplication() {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = activeApp.bundleIdentifier else {
            return
        }
        
        if bundleID != AppState.shared.lastActiveAppIdentifier {
            handleAppSwitch(to: bundleID)
            AppState.shared.lastActiveAppIdentifier = bundleID
        }
    }

    func handleAppSwitch(to appIdentifier: String) {
        print("[AppDelegate] handleAppSwitch: 应用切换到 \(appIdentifier)")
        
        // 避免对自己应用的切换进行处理
        if appIdentifier == Bundle.main.bundleIdentifier {
            print("[AppDelegate] handleAppSwitch: 忽略对自己应用的切换")
            return
        }
        
        // 检查是否有匹配的规则
        if let targetInputSourceID = AppState.shared.appInputSourceMap[appIdentifier] {
            print("[AppDelegate] handleAppSwitch: 找到匹配规则，切换到输入法 ID: \(targetInputSourceID)")
            
            // 设置标志，表示这是程序内部的输入法切换
            isInternalInputSourceChange = true
            
            // 使用带统计记录功能的方法，传递应用切换信息
            let fromAppID = AppState.shared.lastActiveAppIdentifier ?? "unknown"
            InputSourceManager.shared.switchInputSource(
                to: targetInputSourceID, 
                fromAppID: fromAppID, 
                toAppID: appIdentifier
            )
            
            // 短暂延迟后重置标志，确保输入法切换完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isInternalInputSourceChange = false
            }
            
            print("[AppDelegate] handleAppSwitch: 已调用带统计功能的输入法切换方法")
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
        // Only setup if status bar should be visible
        if AppState.shared.hideStatusBarIcon {
            return
        }
        
        AppDelegate.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = AppDelegate.statusItem?.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "TypeSmart Settings")
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
        SimpleLogManager.shared.addLog("Attempting to open settings window.", category: "AppDelegate")
        
        // Try to activate the app to ensure it can display UI, especially if it's an accessory app.
        NSApp.activate(ignoringOtherApps: true)

        if #available(macOS 13.0, *) {
            // This is the standard way to open the Settings scene defined in SwiftUI.
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            SimpleLogManager.shared.addLog("Called NSApp.sendAction for showSettingsWindow.", category: "AppDelegate")
        } else {
            // Fallback for older macOS versions. This needs a concrete implementation.
            SimpleLogManager.shared.addLog("Settings fallback for older macOS triggered - no specific window opening logic implemented here yet.", category: "AppDelegate")
            // Example: Manually find and show your settings window controller or NSHostingController.
            // For instance, if you have a way to identify your settings window:
            // if let settingsWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "mySettingsWindowIdentifier" }) {
            // settingsWindow.makeKeyAndOrderFront(self)
            // } else {
            // // Code to create and show a new settings window instance
            // print("Fallback: Need to implement manual settings window creation and display for older macOS.")
            // }
        }
    }
    
    @objc func refreshAppList() {
        print("Refreshing application list via menu bar.")
        AppState.shared.discoverApplications()
    }
    
    @objc func statusBarVisibilityChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            if AppState.shared.hideStatusBarIcon {
                if let item = AppDelegate.statusItem {
                    NSStatusBar.system.removeStatusItem(item)
                    AppDelegate.statusItem = nil
                }
            } else {
                if AppDelegate.statusItem == nil {
                    self.setupStatusItem()
                }
            }
        }
    }
    
    @objc func requestAccessibilityPermissions() {
        checkAccessibilityPermissions()
    }
}
