import Foundation
import SwiftUI
import ServiceManagement // For SMAppService
import Cocoa // For NSWorkspace, NSImage
import ApplicationServices // For AXIsProcessTrusted

// Notification names for inter-component communication
extension NSNotification.Name {
    static let statusBarVisibilityChanged = NSNotification.Name("statusBarVisibilityChanged")
}

// AppInfo struct: Defines the structure for holding application details.
// It's Identifiable for use in SwiftUI Lists/Pickers.
public struct AppInfo: Identifiable, Hashable, Equatable {
    public let id: String // bundleIdentifier, primary key
    public let name: String
    public let path: URL // URL to the .app bundle

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
public class AppState: ObservableObject {
    public static let shared = AppState() // Singleton instance

    // Maps Bundle Identifier (String) to Input Source ID (String)
    @Published public var appInputSourceMap: [String: String] = [:] {
        didSet {
            if oldValue == appInputSourceMap {
                // print("[AppState] appInputSourceMap.didSet: No actual change. Skipping save.")
                return
            }
            // print("[AppState] appInputSourceMap.didSet: Value changed. Saving rules.")
            SimpleLogManager.shared.addLog("应用输入源映射发生变化，现有 \\(appInputSourceMap.count) 个规则", category: "AppState")
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
            updateDockIconVisibility()
        }
    }
    
    // Manages status bar icon visibility
    @Published public var hideStatusBarIcon: Bool {
        didSet {
            if oldValue == hideStatusBarIcon { return }
            UserDefaults.standard.set(hideStatusBarIcon, forKey: hideStatusBarIconKey)
            NotificationCenter.default.post(name: .statusBarVisibilityChanged, object: hideStatusBarIcon)
        }
    }
    
    // Auto-check permissions on startup
    @Published public var autoCheckPermissions: Bool {
        didSet {
            if oldValue == autoCheckPermissions { return }
            UserDefaults.standard.set(autoCheckPermissions, forKey: autoCheckPermissionsKey)
        }
    }

    private let userDefaultsKey = "appInputSourceMap"
    private let launchAtLoginKey = "launchAtLoginEnabled"
    private let hideDockIconKey = "hideDockIcon"
    private let hideStatusBarIconKey = "hideStatusBarIcon"
    private let autoCheckPermissionsKey = "autoCheckPermissions"

    // Make init public if AppDelegate or other parts need to create it,
    // but for a singleton, private is correct.
    // If InputSwitcherApp.swift uses @StateObject var appState = AppState(), then init() must be public or internal.
    // Since we use AppState.shared, private init() is fine.
    private init() {
        self.launchAtLoginEnabled = UserDefaults.standard.bool(forKey: launchAtLoginKey)
        // 调试时强制重置 dock/status bar 图标显示状态
        #if DEBUG
        self.hideDockIcon = false
        self.hideStatusBarIcon = false
        #else
        self.hideDockIcon = UserDefaults.standard.object(forKey: hideDockIconKey) as? Bool ?? false
        self.hideStatusBarIcon = UserDefaults.standard.bool(forKey: hideStatusBarIconKey)
        #endif
        self.autoCheckPermissions = UserDefaults.standard.object(forKey: autoCheckPermissionsKey) as? Bool ?? true // Default to auto-check
        loadRules()
        print("AppState initialized, rules loaded, and all settings loaded.")
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
            self.discoveredApplications = Array(foundApps).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
            print("Discovered \(self.discoveredApplications.count) unique applications.")
        }
    }

    // Loads saved rules from UserDefaults.
    private func loadRules() {
        if let savedMap = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] {
            appInputSourceMap = savedMap
            print("Loaded \(savedMap.count) rules from UserDefaults.")
        } else {
            print("No saved rules found in UserDefaults or failed to load.")
        }
    }

    // Saves current rules to UserDefaults.
    private func saveRules() {
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
    public func updateDockIconVisibility() {
        DispatchQueue.main.async {
            // 记录设置窗口
            let settingsWindow = NSApp.windows.first { win in
                win.title.contains("设置") || win.title.contains("TypeSmart")
            }
            let wasSettingsVisible = settingsWindow?.isVisible ?? false

            if self.hideDockIcon {
                // 只切换 activationPolicy，不隐藏设置窗口
                NSApp.setActivationPolicy(.accessory)
                SimpleLogManager.shared.addLog("隐藏 Dock 图标", category: "AppState")
            } else {
                NSApp.setActivationPolicy(.regular)
                SimpleLogManager.shared.addLog("显示 Dock 图标", category: "AppState")
                // 恢复设置窗口显示
                if wasSettingsVisible, let win = settingsWindow {
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
            SimpleLogManager.shared.addLog("手动请求辅助功能权限", category: "AppState")
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

// 清除统计数据扩展
extension AppState {
    public func clearStatistics() {
        UserDefaults.standard.removeObject(forKey: "SwitchRecords")
        // 如果有内存中的统计数据，也要清空
        // self.statistics = []
        objectWillChange.send()
    }
}
