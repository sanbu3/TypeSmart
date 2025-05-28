import Foundation
import AppKit
import InputMethodKit
import SwiftUI
import ServiceManagement
import ApplicationServices
import os.log
import Combine

@MainActor
@objcMembers class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState.shared
    private let audioManager = AudioManager.shared
    private let switchRecordManager = SwitchRecordManager.shared
    private let simpleLogManager = SimpleLogManager.shared
    private let inputSourceManager = InputSourceManager.shared
    private let trayManager = TrayManager.shared
    
    var timer: Timer?
    
    // 防止递归切换的标志
    private var isInternalInputSourceChange = false
    private let logger = Logger(subsystem: "online.wangww.TypeSmart", category: "AppDelegate")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("Application did finish launching")
        
        // 修复 GenerativeModelsAvailability 语言代码错误
        setupLanguageEnvironment()
        
        // 检查音效文件是否存在
        let successSound = AppState.shared.successAudioName
        let failureSound = AppState.shared.failureAudioName
        if NSSound(named: successSound) == nil {
            logger.error("[AppDelegate] 成功音效 \(successSound) 未找到")
        }
        if NSSound(named: failureSound) == nil {
            logger.error("[AppDelegate] 失败音效 \(failureSound) 未找到")
        }
        
        // Configure InputSourceManager
        setupInputSourceManager()
        
        // Auto-check permissions if enabled
        if appState.autoCheckPermissions {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                let _ = AXIsProcessTrustedWithOptions(options)
            }
        }
        
        // Apply dock icon visibility setting
        appState.updateDockIconVisibility()
        appState.discoverApplications()
        
        // 恢复丢失的应用信息（名称、路径等）
        appState.recoverMissingApplicationInfo()
        
        // 增强规则中的应用信息，确保所有规则都有完整的AppInfo
        appState.enhanceRuleApplicationInfo()
        
        // 初始化托盘系统
        setupTraySystem()
        
        startTimer()
        
        // 立即检查当前活动应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkActiveApplication()
        }
        
        // 在应用启动时确保设置界面加载侧边栏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.ensureSettingsSidebarLoaded()
        }
    }

    private func setupInputSourceManager() {
        inputSourceManager.configure(
            playSuccessSound: { [weak self] in
                self?.audioManager.playSuccessSound()
            },
            playFailureSound: { [weak self] in
                self?.audioManager.playFailureSound()
            },
            recordSwitch: { [weak self] sourceID, sourceName, bundleID, appName, success in
                self?.switchRecordManager.recordSwitch(
                    sourceID: sourceID,
                    sourceName: sourceName,
                    bundleID: bundleID,
                    appName: appName,
                    success: success
                )
            },
            logMessage: { [weak self] message, category in
                // self?.simpleLogManager.log(message, category: category)
                DispatchQueue.main.async {
                    self?.simpleLogManager.log(message, category: category)
                }
            },
            isAudioFeedbackEnabled: { [weak self] in
                self?.appState.audioFeedbackEnabled ?? false
            }
        )
        logger.info("InputSourceManager configured successfully")
    }

    private func setupTraySystem() {
        // 同步托盘状态
        let trayState = TrayState.shared
        trayManager.isEnabled = trayState.isTrayEnabled
        
        // 初始化托盘管理器
        trayManager.initialize()
        
        // 设置托盘状态监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trayStateChanged),
            name: .trayStateChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trayIconStyleChanged),
            name: .trayIconStyleChanged,
            object: nil
        )
        
        logger.info("Tray system configured successfully - enabled: \(trayState.isTrayEnabled)")
    }
    
    @objc private func trayStateChanged() {
        let trayState = TrayState.shared
        trayManager.isEnabled = trayState.isTrayEnabled
        logger.info("Tray state changed: \(trayState.isTrayEnabled)")
    }
    
    @objc private func trayIconStyleChanged() {
        trayManager.updateTrayIcon()
        logger.info("Tray icon style changed")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        
        // 清理托盘系统
        trayManager.isEnabled = false
        NotificationCenter.default.removeObserver(self)
        
        logger.info("Application terminating, all resources cleaned up")
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
        // 忽略如果自动切换被禁用
        guard appState.autoSwitchEnabled else {
            print("[AppDelegate] 自动切换已禁用，忽略应用切换事件")
            return
        }

        guard let newApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = newApp.bundleIdentifier else {
            print("[AppDelegate] 无法获取切换应用的信息")
            return
        }

        // 防止过于频繁的切换处理
        handleAppSwitchDebounced(to: bundleID)
    }

    private var pendingAppSwitchTimer: Timer?
    private let appSwitchDebounceInterval: TimeInterval = 0.3 // 300ms防抖
    
    @MainActor
    private func handleAppSwitchDebounced(to bundleID: String) {
        pendingAppSwitchTimer?.invalidate()
        pendingAppSwitchTimer = Timer.scheduledTimer(withTimeInterval: appSwitchDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppSwitch(to: bundleID)
            }
        }
    }

    @objc func inputSourceDidChange() {
        // 如果是程序内部的输入法切换，则忽略这个通知
        if isInternalInputSourceChange {
            print("[AppDelegate] 忽略程序内部的输入法变化通知")
            return
        }

        guard let currentInputSourceID = InputSourceManager.shared.getCurrentInputSourceID() else {
            print("[AppDelegate] 外部输入法发生变化，但无法获取当前输入法ID")
            return
        }

        print("[AppDelegate] 外部输入法发生变化，当前输入法ID: \(currentInputSourceID)")
    }

    @objc func checkActiveApplication() {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = activeApp.bundleIdentifier else {
            return
        }
        
        if bundleID != appState.lastActiveAppIdentifier {
            handleAppSwitch(to: bundleID)
            appState.lastActiveAppIdentifier = bundleID
        }
    }

    @MainActor
    func handleAppSwitch(to appIdentifier: String) {
        print("[AppDelegate] handleAppSwitch: 应用切换到 \(appIdentifier)")
        
        // 忽略自身
        if appIdentifier == Bundle.main.bundleIdentifier {
            print("[AppDelegate] handleAppSwitch: 忽略对自己应用的切换")
            return
        }
        
        // 只对有规则的应用进行处理
        guard let targetInputSourceID = appState.appInputSourceMap[appIdentifier] else {
            print("[AppDelegate] handleAppSwitch: 当前应用无规则，不处理输入法切换。BundleID=\(appIdentifier)")
            return
        }
        
        // 获取当前输入法
        guard let currentInputSourceID = InputSourceManager.shared.getCurrentInputSourceID() else {
            print("[AppDelegate] handleAppSwitch: 无法获取当前输入法ID")
            return
        }
        print("[AppDelegate] handleAppSwitch: 规则要求输入法=\(targetInputSourceID)，当前输入法=\(currentInputSourceID)")
        
        if currentInputSourceID == targetInputSourceID {
            print("[AppDelegate] handleAppSwitch: 当前输入法已符合规则，无需切换。")
            return
        }
        
        // 切换输入法
        print("[AppDelegate] handleAppSwitch: 输入法不符，准备切换。from=\(currentInputSourceID) to=\(targetInputSourceID)")
        // SimpleLogManager.shared.addLog("应用 \(appIdentifier) 激活，规则要求输入法 \(targetInputSourceID)，当前为 \(currentInputSourceID)，执行切换。", category: "InputSwitch")
        DispatchQueue.main.async {
            SimpleLogManager.shared.addLog("应用 \(appIdentifier) 激活，规则要求输入法 \(targetInputSourceID)，当前为 \(currentInputSourceID)，执行切换。", category: "InputSwitch")
        }
        
        isInternalInputSourceChange = true
        let fromAppID = appState.lastActiveAppIdentifier ?? "unknown"
        InputSourceManager.shared.switchInputSource(
            to: targetInputSourceID,
            fromAppID: fromAppID,
            toAppID: appIdentifier
        )
        
        // 延迟重置内部切换标志
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isInternalInputSourceChange = false
        }
        
        // 更新最后激活的应用ID
        appState.lastActiveAppIdentifier = appIdentifier
        print("[AppDelegate] handleAppSwitch: 输入法切换已触发。")
        
        // 更新托盘菜单和图标
        trayManager.updateTrayMenu()
        
        // 显示托盘通知（如果用户启用了通知功能）
        if appState.switchNotificationsEnabled {
            let appInfo = appState.discoveredApplications.first { $0.id == appIdentifier }
            let appName = appInfo?.name ?? appIdentifier
            let inputSourceInfo = InputSourceManager.shared.getInputSources().first { $0.id == targetInputSourceID }
            let inputSourceName = inputSourceInfo?.localizedName ?? targetInputSourceID
            
            trayManager.showNotification(
                title: "输入法已切换",
                message: "\(appName) → \(inputSourceName)"
            )
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

    // MARK: - Language Environment Setup
    
    /// 设置正确的语言环境以避免 GenerativeModelsAvailability 错误
    private func setupLanguageEnvironment() {
        // 使用 LocaleManager 获取规范化的语言代码
        let normalizedLanguage = LocaleManager.shared.currentLanguage()
        print("[AppDelegate] 设置语言环境: \(normalizedLanguage)")
        
        // 设置多个环境变量
        setenv("LANG", "\(normalizedLanguage).UTF-8", 1)
        setenv("LC_ALL", "\(normalizedLanguage).UTF-8", 1)
        setenv("LC_MESSAGES", "\(normalizedLanguage).UTF-8", 1)
        setenv("LC_CTYPE", "\(normalizedLanguage).UTF-8", 1)
        setenv("LANGUAGE", normalizedLanguage, 1)
        
        // 强制设置 UserDefaults
        UserDefaults.standard.set([normalizedLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // 使用 CFPreferences 进行全局设置
        CFPreferencesSetValue("AppleLanguages" as CFString, 
                            [normalizedLanguage] as CFArray, 
                            kCFPreferencesAnyApplication, 
                            kCFPreferencesCurrentUser, 
                            kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, 
                               kCFPreferencesCurrentUser, 
                               kCFPreferencesAnyHost)
        
        // 通知系统语言变化
        NotificationCenter.default.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        
        logger.info("Language environment setup complete: \(normalizedLanguage)")
    }

    // 确保设置界面加载侧边栏
    private func ensureSettingsSidebarLoaded() {
        DispatchQueue.main.async {
            if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("设置") || $0.title.contains("TypeSmart") }) {
                if let contentView = settingsWindow.contentView as? NSHostingView<RootSettingsView> {
                    contentView.rootView.loadSidebar()
                    print("[AppDelegate] 确保设置界面加载了侧边栏")
                }
            }
        }
    }
}
