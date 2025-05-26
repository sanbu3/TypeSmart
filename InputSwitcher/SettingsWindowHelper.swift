import SwiftUI
import AppKit

/// Helper class to open settings window with improved compatibility and avoid warnings
class SettingsWindowHelper {
    
    static func openSettingsWindow() {
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Use safe reflection to avoid "Please use SettingsLink for opening the Settings scene" warning
        if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
            // For macOS 13+
            NSApp.perform(Selector(("showSettingsWindow:")))
        } else if NSApp.responds(to: Selector(("showPreferencesWindow:"))) {
            // For macOS 12+
            NSApp.perform(Selector(("showPreferencesWindow:")))
        } else {
            // For older macOS versions
            findOrCreateSettingsWindow()
        }
    }
    
    private static func findOrCreateSettingsWindow() {
        // Try to find an existing settings window first
        if let window = NSApp.windows.first(where: { 
            $0.title.contains("Settings") || 
            $0.title.contains("偏好设置") || 
            $0.title.contains("Preferences") 
        }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // If we got here, we need to create a new settings window
        let contentView = GeneralSettingsView()
            .environmentObject(AppState.shared)
        
        let controller = NSHostingController(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "TypeSmart 设置"
        window.contentViewController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Record log if available
        SimpleLogManager.shared.addLog("创建了设置窗口", category: "UI")
    }
}
