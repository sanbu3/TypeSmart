import AppKit
import Foundation
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
        
        // 恢复丢失的应用信息（名称、路径等）
        AppState.shared.recoverMissingApplicationInfo()
        
        // 增强规则中的应用信息，确保所有规则都有完整的AppInfo
        AppState.shared.enhanceRuleApplicationInfo()
        
        setupStatusItem()
        startTimer()
        
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
        // ⚠️ 不再自动将前台应用添加到规则，避免规则污染
        // 只允许用户在 UI 中手动添加/更新规则
        // 如果需要“记忆”功能，可在设置中提供选项，由用户决定是否启用
        // if let activeApp = NSWorkspace.shared.frontmostApplication,
        //    let bundleID = activeApp.bundleIdentifier,
        //    let currentInputSourceID = InputSourceManager.shared.getCurrentInputSourceID() {
        //     AppState.shared.appInputSourceMap[bundleID] = currentInputSourceID
        //     SimpleLogManager.shared.addLog("检测到用户手动切换输入法，已将 \(bundleID) 的规则更新为 \(currentInputSourceID)", category: "InputSource")
        //     print("[AppDelegate] 规则已更新: \(bundleID) -> \(currentInputSourceID)")
        // }
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
        
        // 忽略自身
        if appIdentifier == Bundle.main.bundleIdentifier {
            print("[AppDelegate] handleAppSwitch: 忽略对自己应用的切换")
            return
        }
        
        // 只对有规则的应用进行处理
        guard let targetInputSourceID = AppState.shared.appInputSourceMap[appIdentifier] else {
            print("[AppDelegate] handleAppSwitch: 当前应用无规则，不处理输入法切换。BundleID=\(appIdentifier)")
            return
        }
        
        // 获取当前输入法
        let currentInputSourceID = InputSourceManager.shared.getCurrentInputSourceID() ?? "(unknown)"
        print("[AppDelegate] handleAppSwitch: 规则要求输入法=\(targetInputSourceID)，当前输入法=\(currentInputSourceID)")
        
        if currentInputSourceID == targetInputSourceID {
            print("[AppDelegate] handleAppSwitch: 当前输入法已符合规则，无需切换。")
            return
        }
        
        // 切换输入法
        print("[AppDelegate] handleAppSwitch: 输入法不符，准备切换。from=\(currentInputSourceID) to=\(targetInputSourceID)")
        SimpleLogManager.shared.addLog("应用 \(appIdentifier) 激活，规则要求输入法 \(targetInputSourceID)，当前为 \(currentInputSourceID)，执行切换。", category: "InputSwitch")
        isInternalInputSourceChange = true
        let fromAppID = AppState.shared.lastActiveAppIdentifier ?? "unknown"
        InputSourceManager.shared.switchInputSource(
            to: targetInputSourceID,
            fromAppID: fromAppID,
            toAppID: appIdentifier
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isInternalInputSourceChange = false
        }
        print("[AppDelegate] handleAppSwitch: 输入法切换已触发。")
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
        // 创建新的状态栏项目，使用 Apple 系统图标
        if AppDelegate.statusItem == nil {
            AppDelegate.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        
        // 配置状态栏按钮，使用 Apple 内置系统图标
        if let button = AppDelegate.statusItem?.button {
            // 使用 Apple 内置的键盘图标
            if #available(macOS 11.0, *) {
                // 优先使用 SF Symbols 中的键盘图标
                if let keyboardIcon = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "TypeSmart 输入法切换器") {
                    button.image = keyboardIcon
                    // 设置图标颜色为系统默认颜色
                    button.image?.isTemplate = true
                } else {
                    // 备选：使用字符图标
                    button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "TypeSmart")
                }
            } else {
                // macOS 10.15 及以下版本的兼容性处理
                if let genericIcon = NSImage(named: NSImage.applicationIconName) {
                    button.image = genericIcon
                } else {
                    // 最终备选：创建一个简单的文本图标
                    let image = NSImage(size: NSSize(width: 16, height: 16))
                    image.lockFocus()
                    "⌨️".draw(at: NSPoint(x: 0, y: 0), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 12)
                    ])
                    image.unlockFocus()
                    button.image = image
                }
                button.image?.isTemplate = true
            }
            
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        // 创建改进的右键菜单
        let menu = NSMenu()
        
        // 添加应用名称作为标题（不可点击）
        let titleItem = NSMenuItem(title: "TypeSmart", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 主要功能菜单项
        let settingsItem = NSMenuItem(title: "偏好设置...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 快速操作
        menu.addItem(NSMenuItem.separator())
        
        let quickToggleItem = NSMenuItem(title: "暂停自动切换", action: #selector(toggleAutoSwitch), keyEquivalent: "")
        quickToggleItem.target = self
        menu.addItem(quickToggleItem)
        
        // 关于和退出
        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(title: "关于 TypeSmart", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "退出 TypeSmart", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        AppDelegate.statusItem?.menu = menu
        print("✅ 新的状态栏图标设置完成，使用 Apple 内置键盘图标")
    }

    @objc func statusItemClicked() {
        openSettingsWindow()
    }

    @objc func openSettingsWindow() {
        // Try to activate the app to ensure it can display UI
        NSApp.activate(ignoringOtherApps: true)
        
        // Proper approach - use Settings item from main menu to avoid "Please use SettingsLink" warning
        if let settingsCommand = NSApp.mainMenu?.items
            .first(where: { $0.title == "TypeSmart" })?
            .submenu?.items
            .first(where: { $0.title.contains("设置") || $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
            if let action = settingsCommand.action {
                NSApp.sendAction(action, to: settingsCommand.target, from: settingsCommand)
            }
            return
        }
        
        // Fallback: Try standard settings API - now deprecated but still functional
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    
    @objc func requestAccessibilityPermissions() {
        checkAccessibilityPermissions()
    }
    
    // MARK: - 新的托盘菜单功能
    
    @objc func toggleAutoSwitch() {
        // 实现暂停/恢复自动切换功能
        AppState.shared.autoSwitchEnabled.toggle()
        
        // 更新菜单项文本
        if let menu = AppDelegate.statusItem?.menu,
           let toggleItem = menu.items.first(where: { $0.action == #selector(toggleAutoSwitch) }) {
            toggleItem.title = AppState.shared.autoSwitchEnabled ? "暂停自动切换" : "恢复自动切换"
        }
        
        let status = AppState.shared.autoSwitchEnabled ? "已恢复" : "已暂停"
        print("🔄 自动切换功能\(status)")
        SimpleLogManager.shared.addLog("自动切换功能\(status)", category: "StatusBar")
    }
    
    @objc func showAbout() {
        // 打开设置窗口并导航到关于页面
        NSApp.activate(ignoringOtherApps: true)
        
        // Use our direct method to open settings without warnings
        openSettingsWindow()
        
        SimpleLogManager.shared.addLog("从状态栏打开关于页面", category: "StatusBar")
    }
}
