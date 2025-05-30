import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation

struct GeneralSettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var requestingPermission = false
    @State private var showMoveToAppFolderAlert = false
    @State private var moveInProgress = false
    @State private var moveError: String? = nil

    @ViewBuilder
    private var applicationsFolderWarningView: some View {
        if !isInApplicationsFolder() {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("The application is not in the Applications folder.")
                }
                Text("为保证权限和自动启动等功能正常，建议将本应用移动到 /Applications 文件夹。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let moveError = moveError {
                    Text("移动失败：\(moveError)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                HStack {
                    Button(action: moveToApplicationsFolder) {
                        if moveInProgress {
                            ProgressView()
                        } else {
                            Label("一键移动到应用程序文件夹", systemImage: "arrow.right.square")
                        }
                    }
                    .disabled(moveInProgress)
                    .buttonStyle(.borderedProminent)
                    Button(action: showManualMoveHelp) {
                        Label("手动操作说明", systemImage: "questionmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                applicationsFolderWarningView // Replaces the original 'if !isInApplicationsFolder()' block
                
                // 功能配置
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("功能配置", systemImage: "gearshape.2")
                                .font(.headline)
                            Spacer()
                        }
                        
                        // 拆分复杂表达式
                        let autoSwitchStatusText = appState.autoSwitchEnabled ? "已启用" : "已暂停"
                        let autoSwitchStatusColor = appState.autoSwitchEnabled ? Color.green : Color.orange

                        Toggle(isOn: $appState.autoSwitchEnabled) {
                            HStack {
                                Label("自动切换输入法", systemImage: "keyboard.fill")
                                Spacer()
                                Text(autoSwitchStatusText)
                                    .font(.caption)
                                    .foregroundColor(autoSwitchStatusColor)
                                    .fontWeight(.medium)
                            }
                        }
                        .help("在不同应用程序间自动切换对应的输入法")
                        
                        Divider()
                        
                        let dockIconStatusText = appState.hideDockIcon ? "已隐藏" : "已显示"
                        let dockIconStatusColor = appState.hideDockIcon ? Color.secondary : Color.blue

                        Toggle(isOn: $appState.hideDockIcon) {
                            HStack {
                                Label("隐藏 Dock 图标", systemImage: "dock.rectangle")
                                Spacer()
                                Text(dockIconStatusText)
                                    .font(.caption)
                                    .foregroundColor(dockIconStatusColor)
                                    .fontWeight(.medium)
                            }
                        }
                        .help("隐藏后可减少视觉干扰，应用仍可通过托盘菜单访问")
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $appState.audioFeedbackEnabled) {
                                HStack {
                                    Label("输入法切换音效", systemImage: "speaker.wave.2.fill")
                                    Spacer()
                                    Text(appState.audioFeedbackEnabled ? "已启用" : "已关闭")
                                        .font(.caption)
                                        .foregroundColor(appState.audioFeedbackEnabled ? .green : .secondary)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .help("切换输入法时播放声音反馈")
                        
                        Divider()
                        
                        // 添加通知控制选项
                        Toggle(isOn: $appState.switchNotificationsEnabled) {
                            HStack {
                                Label("输入法切换通知", systemImage: "bell.badge")
                                Spacer()
                                Text(appState.switchNotificationsEnabled ? "已启用" : "已关闭")
                                    .font(.caption)
                                    .foregroundColor(appState.switchNotificationsEnabled ? .green : .secondary)
                                    .fontWeight(.medium)
                            }
                        }
                        .help("开启后会在切换输入法时显示系统通知，关闭可减少干扰")
                        
                        Divider()
                        
                        // 托盘设置开关
                        let trayStatusText = TrayState.shared.isTrayEnabled ? "已启用" : "已禁用"
                        let trayStatusColor = TrayState.shared.isTrayEnabled ? Color.green : Color.secondary

                        Toggle(isOn: TrayState.shared.trayEnabledBinding) {
                            HStack {
                                Label("显示菜单栏图标", systemImage: "menubar.rectangle")
                                Spacer()
                                Text(trayStatusText)
                                    .font(.caption)
                                    .foregroundColor(trayStatusColor)
                                    .fontWeight(.medium)
                            }
                        }
                        .help("在系统菜单栏中显示 TypeSmart 图标")
                    }
                    .padding()
                }

                // 权限管理
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("权限管理", systemImage: "lock.shield")
                                .font(.headline)
                            Spacer()
                        }
                        
                        HStack {
                            Label("辅助功能权限", systemImage: "hand.raised")
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(appState.checkAccessibilityPermissionsStatus() ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(appState.checkAccessibilityPermissionsStatus() ? "已授权" : "未授权")
                                    .font(.caption)
                                    .foregroundColor(appState.checkAccessibilityPermissionsStatus() ? .green : .red)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if !appState.checkAccessibilityPermissionsStatus() {
                            Divider()
                            
                            Button {
                                requestingPermission = true
                                appState.requestAccessibilityPermissions()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    requestingPermission = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: requestingPermission ? "hourglass" : "person.badge.key")
                                    Text(requestingPermission ? "正在请求权限..." : "申请辅助功能权限")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(requestingPermission)
                            .help("如未弹出系统授权窗口，请手动前往系统设置-隐私-辅助功能添加 TypeSmart")
                        }
                    }
                    .padding()
                }

                // 启动设置
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("启动设置", systemImage: "power")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Toggle(isOn: $appState.launchAtLoginEnabled) {
                            HStack {
                                Label("开机自动启动", systemImage: "bolt.fill")
                                Spacer()
                                Text(appState.launchAtLoginEnabled ? "已启用" : "已禁用")
                                    .font(.caption)
                                    .foregroundColor(appState.launchAtLoginEnabled ? .green : .secondary)
                                    .fontWeight(.medium)
                            }
                        }
                        .help("TypeSmart 会随系统自动启动")
                        
                        Divider()
                        
                        Toggle(isOn: $appState.autoCheckPermissions) {
                            HStack {
                                Label("启动时自动检测权限", systemImage: "checkmark.shield")
                                Spacer()
                                Text(appState.autoCheckPermissions ? "已启用" : "已禁用")
                                    .font(.caption)
                                    .foregroundColor(appState.autoCheckPermissions ? .green : .secondary)
                                    .fontWeight(.medium)
                            }
                        }
                        .help("每次启动时自动检测并申请辅助功能权限")
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            _ = appState.checkAccessibilityPermissionsStatus()
        }
    }

    // 检查当前App是否在/Applications目录
    private func isInApplicationsFolder() -> Bool {
        let appPath = Bundle.main.bundlePath
        return appPath.hasPrefix("/Applications") || appPath.hasPrefix("/System/Applications")
    }

    // 自动移动到/Applications并重启（带权限提升，失败时自动弹出Finder）
    private func moveToApplicationsFolder() {
        moveInProgress = true
        moveError = nil
        let srcPath = Bundle.main.bundlePath
        let appName = (srcPath as NSString).lastPathComponent
        let destPath = "/Applications/\(appName)"
        let script = "do shell script \"cp -R '\(srcPath)' '\(destPath)'\" with administrator privileges"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            if error == nil {
                // 拷贝成功，重启新副本
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-n", destPath]
                try? task.run()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            } else {
                moveError = error?[NSAppleScript.errorMessage] as? String ?? "未知错误，可能已取消或权限不足"
                // 自动弹出 Finder，方便手动拖动
                let appURL = URL(fileURLWithPath: srcPath)
                NSWorkspace.shared.activateFileViewerSelecting([appURL])
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
            }
        } else {
            moveError = "无法创建权限请求脚本"
            let appURL = URL(fileURLWithPath: srcPath)
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        }
        moveInProgress = false
    }

    // 手动操作说明弹窗
    private func showManualMoveHelp() {
        let alert = NSAlert()
        alert.messageText = "如何手动移动 TypeSmart 到应用程序文件夹？"
        alert.informativeText = "1. 关闭本应用\n2. 在访达中将 TypeSmart 拖动到 /Applications 文件夹\n3. 重新打开 TypeSmart"
        alert.alertStyle = .informational
        alert.runModal()
    }
}

struct AlwaysOnTopWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .floating
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
