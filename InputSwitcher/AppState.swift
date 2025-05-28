import Foundation
import SwiftUI
import ServiceManagement // For SMAppService
import Cocoa // For NSWorkspace, NSImage
import ApplicationServices // For AXIsProcessTrusted
import os.log
import Combine
import AudioToolbox // 添加缺少的框架导入

// Access managers directly without module imports

// AppInfo struct: Defines the structure for holding application details.
// It's Identifiable for use in SwiftUI Lists/Pickers.
public struct AppInfo: Identifiable, Hashable, Equatable, Codable {
    public let id: String // bundleIdentifier, primary key
    public let name: String
    public let path: URL // URL to the .app bundle
    
    // Keys for Codable
    enum CodingKeys: String, CodingKey {
        case id, name, path
    }

    // Computed property to get the application icon
    public var icon: NSImage? {
        if let values = try? path.resourceValues(forKeys: [.effectiveIconKey]),
           let icon = values.effectiveIcon as? NSImage {
            return icon
        } else if let bundle = Bundle(url: path),
                  let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
                  let iconImage = NSImage(contentsOfFile: path.appendingPathComponent("Contents/Resources/").appendingPathComponent(iconName).path) {
            return iconImage
        } else if let bundle = Bundle(url: path),
                  let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String,
                  let iconImage = NSImage(named: iconName) { // For icons in AppIcon.appiconset
             return iconImage
        }
        // Fallback to a generic app icon if specific one not found
        return NSWorkspace.shared.icon(forFile: path.path)
    }

    public static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// AppState class: Manages the application's shared state.
// ObservableObject for SwiftUI to observe changes.
public final class AppState: ObservableObject {
    public static let shared = AppState() // Singleton instance

    // Maps Bundle Identifier (String) to Input Source ID (String)
    @Published public var appInputSourceMap: [String: String] = [:] {
        didSet {
            if oldValue == appInputSourceMap {
                // print("[AppState] appInputSourceMap.didSet: No actual change. Skipping save.")
                return
            }
            // print("[AppState] appInputSourceMap.didSet: Value changed. Saving rules.")
            // 使用普通日志记录代替 SimpleLogManager
            DispatchQueue.main.async {
                print("[AppState] 应用输入源映射发生变化，现有 \\(self.appInputSourceMap.count) 个规则")
            }
            saveRules()
        }
    }
    // List of discovered applications (AppInfo structs)
    @Published public var discoveredApplications: [AppInfo] = []
    // Stores the bundle ID of the last known active application
    @Published public var lastActiveAppIdentifier: String?
    // Manages launch at login state
    @Published public var launchAtLoginEnabled: Bool {
        didSet {
            if oldValue == launchAtLoginEnabled { return }

            if #available(macOS 13.0, *) {
                do {
                    if launchAtLoginEnabled {
                        try SMAppService.mainApp.register()
                        print("Successfully registered for launch at login.")
                    } else {
                        try SMAppService.mainApp.unregister()
                        print("Successfully unregistered from launch at login.")
                    }
                    UserDefaults.standard.set(launchAtLoginEnabled, forKey: launchAtLoginKey)
                } catch {
                    print("Failed to update launch at login status: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.launchAtLoginEnabled = oldValue
                    }
                }
            } else {
                UserDefaults.standard.set(launchAtLoginEnabled, forKey: launchAtLoginKey)
                print("Launch at login preference saved. For macOS versions older than 13.0, manual configuration might be needed or this feature may not be fully supported without a helper application.")
            }
        }
    }
    
    // Manages dock icon visibility
    @Published public var hideDockIcon: Bool {
        didSet {
            if oldValue == hideDockIcon { return }
            UserDefaults.standard.set(hideDockIcon, forKey: hideDockIconKey)
            print("[AppState] hideDockIcon toggled: \(hideDockIcon)")
            // 自动更新 Dock 图标可见性
            updateDockIconVisibility()
        }
    }
    

    
    // Auto-check permissions on startup
    @Published public var autoCheckPermissions: Bool {
        didSet {
            if oldValue == autoCheckPermissions { return }
            UserDefaults.standard.set(autoCheckPermissions, forKey: autoCheckPermissionsKey)
        }
    }
    
    // Control auto-switching functionality
    @Published public var autoSwitchEnabled: Bool {
        didSet {
            if oldValue == autoSwitchEnabled { return }
            UserDefaults.standard.set(autoSwitchEnabled, forKey: autoSwitchEnabledKey)
        }
    }
    
    // 控制音频反馈功能
    @Published public var audioFeedbackEnabled: Bool {
        didSet {
            if oldValue == audioFeedbackEnabled { return }
            UserDefaults.standard.set(audioFeedbackEnabled, forKey: audioFeedbackEnabledKey)
        }
    }
    
    // 音频音量控制，添加错误处理
    @Published public var audioVolume: Float {
        didSet {
            if oldValue == audioVolume { return }
            // 确保音量值在有效范围内
            let clampedVolume = max(0.0, min(1.0, audioVolume))
            if clampedVolume != audioVolume {
                audioVolume = clampedVolume
            }
            UserDefaults.standard.set(clampedVolume, forKey: audioVolumeKey)
        }
    }
    
    // 初始化存储属性时直接从 UserDefaults 获取值
    @Published public var successAudioName: String = UserDefaults.standard.string(forKey: "successAudioName") ?? "Frog" {
        didSet {
            if oldValue != successAudioName {
                UserDefaults.standard.set(successAudioName, forKey: "successAudioName")
            }
        }
    }
    
    @Published public var failureAudioName: String = UserDefaults.standard.string(forKey: "failureAudioName") ?? "Purr" {
        didSet {
            if oldValue != failureAudioName {
                UserDefaults.standard.set(failureAudioName, forKey: "failureAudioName")
            }
        }
    }
    
    // 控制输入法切换通知功能
    @Published public var switchNotificationsEnabled: Bool {
        didSet {
            if oldValue == switchNotificationsEnabled { return }
            UserDefaults.standard.set(switchNotificationsEnabled, forKey: switchNotificationsEnabledKey)
        }
    }

    public var availableAudioNames: [String] {
        return ["Frog", "Purr", "Jump", "Tink", "Pop", "Blow", "Basso", "Glass", "Ping", "Bottle"]
    }

    private let userDefaultsKey = "appInputSourceMap"
    private let launchAtLoginKey = "launchAtLoginEnabled"
    private let hideDockIconKey = "hideDockIcon"
    private let autoCheckPermissionsKey = "autoCheckPermissions"
    private let autoSwitchEnabledKey = "autoSwitchEnabled"
    private let discoveredAppsKey = "discoveredApplications"
    private let audioFeedbackEnabledKey = "audioFeedbackEnabled"
    private let audioVolumeKey = "audioVolume"
    private let switchNotificationsEnabledKey = "switchNotificationsEnabled"

    // Make init public if AppDelegate or other parts need to create it,
    // but for a singleton, private is correct.
    // If InputSwitcherApp.swift uses @StateObject var appState = AppState(), then init() must be public or internal.
    // Since we use AppState.shared, private init() is fine.
    private init() {
        self.launchAtLoginEnabled = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        #if DEBUG
        self.hideDockIcon = false
        #else
        self.hideDockIcon = UserDefaults.standard.object(forKey: hideDockIconKey) as? Bool ?? false
        #endif
        self.autoCheckPermissions = UserDefaults.standard.object(forKey: autoCheckPermissionsKey) as? Bool ?? true // Default to auto-check
        self.autoSwitchEnabled = UserDefaults.standard.object(forKey: autoSwitchEnabledKey) as? Bool ?? true // Default to enabled
        self.audioFeedbackEnabled = UserDefaults.standard.object(forKey: audioFeedbackEnabledKey) as? Bool ?? true // 默认启用音频反馈
        self.audioVolume = UserDefaults.standard.object(forKey: audioVolumeKey) as? Float ?? 1.0 // Default to full volume
        self.switchNotificationsEnabled = UserDefaults.standard.object(forKey: switchNotificationsEnabledKey) as? Bool ?? false // 默认不发送通知
        loadRules()
        loadDiscoveredApplications() // Load saved app metadata
        print("AppState initialized, rules loaded, and all settings loaded.")
        print("[AppState DEBUG] Initial audioFeedbackEnabled: \\(self.audioFeedbackEnabled)")
        print("[AppState DEBUG] Initial audioVolume: \\(self.audioVolume)")
    }

    // Discovers applications from standard locations.
    public func discoverApplications() {
        print("Starting application discovery...")
        var foundApps: Set<AppInfo> = []
        let fileManager = FileManager.default
        
        var appDirectoriesPaths: [String] = ["/Applications", "/System/Applications"]
        if let userAppsDir = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first?.path {
            if !appDirectoriesPaths.contains(userAppsDir) { // Avoid duplicates if /Applications is same as user's
                appDirectoriesPaths.append(userAppsDir)
            }
        }

        for dirPath in appDirectoriesPaths {
            // Ensure dirPath is a valid path string before creating URL
            guard !dirPath.isEmpty,
                  let dirURL = URL(string: "file://\\(dirPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? dirPath)") else {
                print("Failed to create URL for directory or invalid path: \\(dirPath)")
                continue
            }
            do {
                let appURLs = try fileManager.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.localizedNameKey, .isDirectoryKey, .isApplicationKey, .effectiveIconKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
                
                for appURL in appURLs where appURL.pathExtension.lowercased() == "app" {
                    guard let bundle = Bundle(url: appURL),
                          let bundleID = bundle.bundleIdentifier,
                          let isApp = try? appURL.resourceValues(forKeys: [.isApplicationKey]).isApplication, isApp == true
                    else {
                        continue
                    }

                    let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                                  (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                                  appURL.deletingPathExtension().lastPathComponent
                    
                    foundApps.insert(AppInfo(id: bundleID, name: appName, path: appURL))
                }
            } catch {
                print("Error discovering applications in \(dirPath): \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async {
            let newlyDiscovered = Array(foundApps).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
            self.mergeDiscoveredApplications(newlyDiscovered)
            print("Discovered \(newlyDiscovered.count) applications, merged with saved data. Total: \(self.discoveredApplications.count)")
        }
        
        // 合并所有规则中 bundleID 的 AppInfo，保证规则区始终有图标和名称
        self.mergeRulesToApplications()
    }

    // 合并所有规则中 bundleID 的 AppInfo，保证规则区始终有图标和名称
    public func mergeRulesToApplications() {
        let allRuleIDs = Set(appInputSourceMap.keys)
        var merged = Dictionary(uniqueKeysWithValues: discoveredApplications.map { ($0.id, $0) })
        for bundleID in allRuleIDs {
            if merged[bundleID] == nil {
                // 占位 AppInfo
                let placeholder = AppInfo(
                    id: bundleID,
                    name: bundleID,
                    path: URL(fileURLWithPath: "/Applications")
                )
                merged[bundleID] = placeholder
            }
        }
        discoveredApplications = Array(merged.values).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // 在 discoverApplications 后自动补全
    public func discoverApplicationsAndMergeRules() {
        discoverApplications()
        mergeRulesToApplications()
    }

    // Loads saved rules from UserDefaults.
    public func loadRules() {
        if let savedMap = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] {
            appInputSourceMap = savedMap
            print("Loaded \(savedMap.count) rules from UserDefaults.")
        } else {
            print("No saved rules found in UserDefaults or failed to load.")
        }
    }

    // Saves current rules to UserDefaults.
    public func saveRules() {
        UserDefaults.standard.set(appInputSourceMap, forKey: userDefaultsKey)
        print("Saved \(appInputSourceMap.count) rules to UserDefaults.")
    }
    
    public func loadLaunchAtLoginState() {
        let storedValue = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        if self.launchAtLoginEnabled != storedValue {
            self.launchAtLoginEnabled = storedValue
        }
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled && !self.launchAtLoginEnabled {
                print("Launch at login was enabled externally, syncing state.")
            } else if SMAppService.mainApp.status == .notRegistered && self.launchAtLoginEnabled {
                 print("Launch at login was disabled externally or failed to register, syncing state.")
            }
        }
        print("[AppState] Loaded launchAtLoginEnabled state from UserDefaults: \(self.launchAtLoginEnabled)")
    }

    // This function might not be needed if didSet on launchAtLoginEnabled handles saving.
    // However, if there are other ways launchAtLoginEnabled could be set that bypass didSet,
    // or if you want an explicit save point, it could be useful.
    // For now, assuming didSet is sufficient.
    // private func saveLaunchAtLoginState() {
    //     UserDefaults.standard.set(launchAtLoginEnabled, forKey: launchAtLoginKey)
    //     print("Saved launchAtLoginEnabled state to UserDefaults: \(self.launchAtLoginEnabled)")
    // }
    
    // Update dock icon visibility
    private var settingsWindow: NSWindow?

    public func updateDockIconVisibility() {
        DispatchQueue.main.async {
            // 记录当前活跃的设置窗口
            self.settingsWindow = NSApp.windows.first { win in
                win.title.contains("设置") || win.title.contains("TypeSmart") || win.title.contains("Settings")
            }
            let wasSettingsVisible = self.settingsWindow?.isVisible ?? false

            if self.hideDockIcon {
                // 切换到辅助应用模式，隐藏 Dock 图标
                NSApp.setActivationPolicy(.accessory)
                print("[AppState] 已隐藏 Dock 图标，应用切换为辅助模式")
                
                // 如果设置窗口之前是可见的，保持其可见状态和焦点
                if wasSettingsVisible, let win = self.settingsWindow {
                    // 在辅助模式下，需要强制激活应用和窗口
                    NSApp.activate(ignoringOtherApps: true)
                    win.makeKeyAndOrderFront(nil)
                    // 确保窗口层级足够高，不被其他窗口遮挡
                    win.level = .floating
                    // 短暂延迟后恢复正常层级
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        win.level = .normal
                        win.makeKeyAndOrderFront(nil)
                    }
                }
            } else {
                // 切换到常规应用模式，显示 Dock 图标
                NSApp.setActivationPolicy(.regular)
                print("[AppState] 已显示 Dock 图标，应用切换为常规模式")
                
                // 恢复设置窗口的显示状态
                if wasSettingsVisible, let win = self.settingsWindow {
                    NSApp.activate(ignoringOtherApps: true)
                    win.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    // Check accessibility permissions without prompt
    public func checkAccessibilityPermissionsStatus() -> Bool {
        return AXIsProcessTrusted()
    }
    
    // Check accessibility permissions with optional prompt
    public func checkAccessibilityPermissions(showPrompt: Bool = false) -> Bool {
        if showPrompt {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            return AXIsProcessTrustedWithOptions(options)
        } else {
            return AXIsProcessTrusted()
        }
    }
    
    // Request accessibility permissions manually
    public func requestAccessibilityPermissions() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let _ = AXIsProcessTrustedWithOptions(options)
            print("[AppState] 手动请求辅助功能权限")
        }
    }
    
    // Check all permissions and return status
    public func checkAllPermissions() -> [String: Bool] {
        var permissions: [String: Bool] = [:]
        
        // Accessibility permission
        permissions["accessibility"] = checkAccessibilityPermissionsStatus()
        
        // Add other permission checks here as needed
        // For example: input monitoring, full disk access, etc.
        
        return permissions
    }
}

// MARK: - App Metadata Persistence
    
extension AppState {
    /// Saves the current discovered applications to UserDefaults
    private func saveDiscoveredApplications() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(discoveredApplications)
            UserDefaults.standard.set(data, forKey: discoveredAppsKey)
            print("Saved \(discoveredApplications.count) discovered applications to UserDefaults")
        } catch {
            print("Failed to save discovered applications: \(error)")
        }
    }
    
    /// Loads previously discovered applications from UserDefaults
    private func loadDiscoveredApplications() {
        guard let data = UserDefaults.standard.data(forKey: discoveredAppsKey) else {
            print("No saved discovered applications found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let savedApps = try decoder.decode([AppInfo].self, from: data)
            
            // Filter out apps that no longer exist on the system
            let existingApps = savedApps.filter { app in
                FileManager.default.fileExists(atPath: app.path.path)
            }
            
            self.discoveredApplications = existingApps
            print("Loaded \(existingApps.count) discovered applications from UserDefaults")
            
            if existingApps.count < savedApps.count {
                print("Removed \(savedApps.count - existingApps.count) applications that no longer exist")
                // Save the cleaned list
                saveDiscoveredApplications()
            }
        } catch {
            print("Failed to load discovered applications: \(error)")
        }
    }
    
    /// Merges newly discovered apps with saved apps, preserving metadata
    private func mergeDiscoveredApplications(_ newApps: [AppInfo]) {
        var mergedApps: [String: AppInfo] = [:]
        
        // Start with existing saved apps
        for app in discoveredApplications {
            mergedApps[app.id] = app
        }
        
        // Add or update with newly discovered apps
        for app in newApps {
            mergedApps[app.id] = app
        }
        
        // Convert back to array and sort
        self.discoveredApplications = Array(mergedApps.values).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        
        // Save the merged list
        saveDiscoveredApplications()
    }
}

// 清除统计数据扩展
extension AppState {
    public func clearStatistics() {
        UserDefaults.standard.removeObject(forKey: "SwitchRecords")
        // 如果有内存中的统计数据，也要清空
        // self.statistics = []
        objectWillChange.send()
    }
    
    // MARK: - Application Recovery and Enhancement
    
    /// 恢复丢失的应用信息，主要用于应用重启后数据恢复
    public func recoverMissingApplicationInfo() {
        var needsSave = false
        var updatedApps: [AppInfo] = []
        
        for app in discoveredApplications {
            var updatedApp = app
            var isUpdated = false
            
            // 检查应用名称是否为Bundle ID（表示名称丢失）
            if app.name == app.id {
                // 尝试通过Bundle ID查找真实的应用名称
                if let recoveredInfo = recoverAppInfoByBundleID(app.id) {
                    updatedApp = AppInfo(
                        id: app.id,
                        name: recoveredInfo.name,
                        path: recoveredInfo.path
                    )
                    isUpdated = true
                    DispatchQueue.main.async {
                        print("[AppState] 恢复应用 \\(app.id) 的名称: \\(recoveredInfo.name)")
                    }
                }
            }
            
            // 检查应用路径是否仍然有效
            if !FileManager.default.fileExists(atPath: app.path.path) {
                // 应用路径无效，尝试查找新位置
                if let recoveredInfo = recoverAppInfoByBundleID(app.id) {
                    updatedApp = AppInfo(
                        id: app.id,
                        name: recoveredInfo.name.isEmpty ? app.name : recoveredInfo.name,
                        path: recoveredInfo.path
                    )
                    isUpdated = true
                    DispatchQueue.main.async {
                        print("[AppState] 恢复应用 \\(app.id) 的路径: \\(recoveredInfo.path.path)")
                    }
                }
            }
            
            if isUpdated {
                needsSave = true
            }
            
            updatedApps.append(updatedApp)
        }
        
        // 更新discoveredApplications并保存
        if needsSave {
            discoveredApplications = updatedApps.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
            saveDiscoveredApplications()
            DispatchQueue.main.async {
                print("[AppState] 应用信息恢复完成，更新了 \\(self.discoveredApplications.count) 个应用")
            }
        }
    }
    
    /// 通过Bundle ID查找并恢复应用信息
    private func recoverAppInfoByBundleID(_ bundleID: String) -> AppInfo? {
        // 1. 使用NSWorkspace查找应用
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            if let bundle = Bundle(url: appURL) {
                let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                             (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                             appURL.deletingPathExtension().lastPathComponent
                
                return AppInfo(id: bundleID, name: appName, path: appURL)
            }
        }
        
        // 2. 在常见目录中搜索
        let searchPaths = ["/Applications", "/System/Applications", "/Applications/Utilities"]
        
        for searchPath in searchPaths {
            let directoryURL = URL(fileURLWithPath: searchPath)
            
            do {
                let appURLs = try FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isApplicationKey],
                    options: [.skipsHiddenFiles]
                )
                
                for appURL in appURLs where appURL.pathExtension.lowercased() == "app" {
                    if let bundle = Bundle(url: appURL),
                       bundle.bundleIdentifier == bundleID {
                        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                                     (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                                     appURL.deletingPathExtension().lastPathComponent
                        
                        return AppInfo(id: bundleID, name: appName, path: appURL)
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    /// 增强规则映射中的应用信息，为规则中的Bundle ID添加完整的AppInfo
    public func enhanceRuleApplicationInfo() {
        let allRuleBundleIDs = Set(appInputSourceMap.keys)
        var enhancedApps: [String: AppInfo] = [:]
        
        // 保留现有的应用信息
        for app in discoveredApplications {
            enhancedApps[app.id] = app
        }
        
        // 为规则中缺失的Bundle ID添加信息
        for bundleID in allRuleBundleIDs {
            if enhancedApps[bundleID] == nil {
                // 尝试恢复应用信息
                if let recoveredInfo = recoverAppInfoByBundleID(bundleID) {
                    enhancedApps[bundleID] = recoveredInfo
                    DispatchQueue.main.async {
                        print("[AppState] 为规则增强应用信息: \\(bundleID) -> \\(recoveredInfo.name)")
                    }
                } else {
                    // 创建占位符，使用Bundle ID作为名称
                    enhancedApps[bundleID] = AppInfo(
                        id: bundleID,
                        name: bundleID,
                        path: URL(fileURLWithPath: "/Applications") // 占位路径
                    )
                    DispatchQueue.main.async {
                        print("[AppState] 为规则创建占位符: \\(bundleID)")
                    }
                }
            }
        }
        
        // 更新discoveredApplications
        discoveredApplications = Array(enhancedApps.values).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        saveDiscoveredApplications()
    }
    
    // 添加动态获取系统音效的方法
    public func fetchAvailableSystemSounds() -> [String] {
        let soundDirectories = [
            "/System/Library/Sounds",
            "/Library/Sounds",
            "~/Library/Sounds"
        ]

        var systemSounds: [String] = []
        let fileManager = FileManager.default

        for directory in soundDirectories {
            let expandedPath = (directory as NSString).expandingTildeInPath
            if let soundFiles = try? fileManager.contentsOfDirectory(atPath: expandedPath) {
                for file in soundFiles where file.hasSuffix(".aiff") || file.hasSuffix(".wav") {
                    systemSounds.append((file as NSString).deletingPathExtension)
                }
            }
        }

        return systemSounds
    }
    
    public func playNotificationSound(isSuccess: Bool) {
        let audioName = isSuccess ? successAudioName : failureAudioName

        // 如果用户未设置音效，使用默认音效
        let soundToPlay = audioName.isEmpty ? (isSuccess ? "Frog" : "Purr") : audioName

        if let sound = NSSound(named: soundToPlay) {
            if !sound.isPlaying {
                sound.play()
                print("[AppState] 播放音效: \(soundToPlay)")
            }
        } else {
            // 备用方案：使用系统音效或提示音
            let fallbackSound = isSuccess ? "Tink" : "Basso"
            if let fallback = NSSound(named: fallbackSound) {
                fallback.play()
                print("[AppState] 使用备用音效: \(fallbackSound)")
            } else {
                NSSound.beep()
                print("[AppState] 音效 \(soundToPlay) 未找到，使用系统提示音。")
            }
        }
    }
    
    // 添加音频配置验证方法
    public func validateAudioConfiguration() {
        // 确保音量在有效范围内
        if audioVolume < 0.0 || audioVolume > 1.0 {
            print("[AppState] 音频音量超出范围: \(audioVolume)，重置为1.0")
            audioVolume = 1.0
        }
        
        // 验证成功音效名称
        let availableSounds = availableAudioNames
        if !successAudioName.isEmpty && !availableSounds.contains(successAudioName) {
            print("[AppState] 成功音效名称无效: \(successAudioName)，重置为Frog")
            successAudioName = "Frog"
        }
        
        // 验证失败音效名称
        if !failureAudioName.isEmpty && !availableSounds.contains(failureAudioName) {
            print("[AppState] 失败音效名称无效: \(failureAudioName)，重置为Purr")
            failureAudioName = "Purr"
        }
        
        print("[AppState] 音频配置验证完成 - 音量: \(audioVolume), 成功音效: \(successAudioName), 失败音效: \(failureAudioName)")
    }
}
