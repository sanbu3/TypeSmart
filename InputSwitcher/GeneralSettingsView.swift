import SwiftUI
import Cocoa

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // 统一的视图内边距
    private let viewPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 20
    private let contentSpacing: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // 页面标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用设置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("配置 InputSwitcher 的基本设置和行为")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 启动设置
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("启动设置", systemImage: "power")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $appState.launchAtLoginEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("开机启动")
                                        .font(.body)
                                    Text("系统启动时自动运行 InputSwitcher")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle())
                        }
                    }
                    .padding(contentSpacing)
                }
                
                // 应用管理
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("应用管理", systemImage: "app.badge")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                appState.discoverApplications()
                            }) {
                                Label("刷新应用列表", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("重新扫描系统中已安装的应用程序")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(contentSpacing)
                }
                
                // 更新和支持
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("更新和支持", systemImage: "arrow.down.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                // TODO: 实现检查更新逻辑
                                print("Check for updates button clicked.")
                                let alert = NSAlert()
                                alert.messageText = "检查更新"
                                alert.informativeText = "当前版本已是最新版本。"
                                alert.alertStyle = .informational
                                alert.runModal()
                            }) {
                                Label("检查更新", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("检查是否有可用的应用程序更新")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(contentSpacing)
                }
                
                Spacer(minLength: 0)
            }
            .padding(viewPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // For previews, create a temporary AppState instance or use the shared one.
        // Using AppState.shared is fine if its initialization doesn't have side effects
        // that are problematic for previews.
        GeneralSettingsView()
            .environmentObject(AppState.shared) // Provide the AppState to the preview
    }
}