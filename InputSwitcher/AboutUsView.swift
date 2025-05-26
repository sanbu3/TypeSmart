import SwiftUI
import AppKit

struct AboutUsView: View {
    // 统一的视图内边距
    private let viewPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 20
    private let contentSpacing: CGFloat = 16
    
    var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }
    var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // 页面标题和图标
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard.badge.ellipsis")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TypeSmart")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("智能输入法切换助手")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 应用信息
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("应用信息", systemImage: "info.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(title: "版本", value: "1.8.0", systemImage: "number.circle")
                            InfoRow(title: "构建号", value: "20250526", systemImage: "hammer.circle")
                            InfoRow(title: "系统要求", value: "macOS 15.4+", systemImage: "desktopcomputer.and.arrow.down")
                            InfoRow(title: "开发者", value: "王汪旺", systemImage: "person.circle")
                        }
                    }
                    .padding(contentSpacing)
                }
                
                // 功能介绍
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("功能特色", systemImage: "star.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(
                                title: "智能切换",
                                description: "根据当前使用的应用程序自动切换输入法",
                                systemImage: "arrow.triangle.swap"
                            )
                            
                            FeatureRow(
                                title: "规则管理",
                                description: "为不同应用设置特定的输入法规则",
                                systemImage: "list.star"
                            )
                            
                            FeatureRow(
                                title: "使用统计",
                                description: "查看输入法切换的使用情况和统计数据",
                                systemImage: "chart.bar"
                            )
                            
                            FeatureRow(
                                title: "后台运行",
                                description: "在系统状态栏中静默运行，不影响日常使用",
                                systemImage: "moon.circle"
                            )
                        }
                    }
                    .padding(contentSpacing)
                }
                
                // 支持和反馈
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("支持和反馈", systemImage: "questionmark.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Link(destination: URL(string: "https://www.wangww.online")!) {
                                    Label("访问官网", systemImage: "globe")
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Link(destination: URL(string: "mailto:sanbuwang@foxmail.com")!) {
                                    Label("联系支持 (sanbuwang@foxmail.com)", systemImage: "envelope")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Text("如有问题或建议，欢迎通过以上方式联系我们")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(contentSpacing)
                }
                
                // 内置帮助
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("内置帮助", systemImage: "book.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("• 应用无法启动：请确保已授予必要的系统权限，或右键选择'打开'")
                            Text("• 输入法切换不工作：请检查辅助功能权限，并确认规则设置正确")
                            Text("• 数据丢失：应用数据保存在用户目录 Library 文件夹，可通过日志功能查看记录")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(contentSpacing)
                }
                
                // 版权信息
                VStack(spacing: 8) {
                    Text("© 2024 王汪旺 (wangww.online). All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Built with ❤️ using SwiftUI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, sectionSpacing)
                
                Spacer(minLength: 0)
            }
            .padding(viewPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func moveAppToApplicationsFolder() {
        let fileManager = FileManager.default
        let appPath = Bundle.main.bundlePath
        let destPath = "/Applications/" + (appPath as NSString).lastPathComponent
        do {
            if fileManager.fileExists(atPath: destPath) {
                try fileManager.removeItem(atPath: destPath)
            }
            try fileManager.copyItem(atPath: appPath, toPath: destPath)
            let alert = NSAlert()
            alert.messageText = "已移动到“应用程序”文件夹"
            alert.informativeText = "请从“应用程序”文件夹重新启动 TypeSmart。"
            alert.runModal()
            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "移动失败"
            alert.informativeText = "无法移动到 /Applications，请手动操作。\n错误信息：\(error.localizedDescription)"
            alert.runModal()
        }
    }
}

// MARK: - Helper Views
private struct InfoRow: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

private struct FeatureRow: View {
    let title: String
    let description: String
    let systemImage: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

struct AboutUsView_Previews: PreviewProvider {
    static var previews: some View {
        AboutUsView()
    }
}
