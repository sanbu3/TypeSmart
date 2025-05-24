import SwiftUI
import Cocoa

@main
struct InputSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState.shared
    @StateObject var switchRecordManager = SwitchRecordManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        
        #if os(macOS)
        Settings {
            GeneralSettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}
