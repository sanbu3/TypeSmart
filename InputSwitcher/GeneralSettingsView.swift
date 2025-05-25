import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var requestingPermission = false
    @State private var showMoveAppSheet = false

    // 统一的视图内边距和间距
    private let viewPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 20
    private let contentSpacing: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) { // 统一的垂直间距
                // 界面设置
                GroupBox(label: Label("界面设置", systemImage: "paintbrush").font(.headline).padding(.top, sectionSpacing).padding(.bottom, sectionSpacing)) {
                    VStack(alignment: .leading, spacing: contentSpacing) { // 统一的内容间距
                        Toggle(isOn: $appState.hideDockIcon) {
                            Label("隐藏 Dock 栏图标", systemImage: "dock.rectangle")
                        }
                        .help("关闭后，TypeSmart 会在 Dock 栏显示图标，便于从任务栏切回应用。")

                        Toggle(isOn: $appState.hideStatusBarIcon) {
                            Label(appState.hideStatusBarIcon ? "不在菜单栏显示" : "在菜单栏显示", systemImage: appState.hideStatusBarIcon ? "menubar.arrow.up.rectangle" : "menubar.dock.rectangle")
                        }
                        .help("控制 TypeSmart 是否在屏幕顶部菜单栏显示快捷入口。")
                    }
                    .padding(viewPadding) // 统一的内边距
                }

                // 应用程序管理
                GroupBox(label: Label("应用程序管理", systemImage: "folder").font(.headline).padding(.top, sectionSpacing).padding(.bottom, sectionSpacing)) {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Text("⚠️ 建议将 TypeSmart 移动到“应用程序”文件夹，以获得最佳兼容性。")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Button {
                            showMoveAppSheet = true
                        } label: {
                            Label("移动到应用程序文件夹", systemImage: "folder")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("将 TypeSmart 移动到 /Applications 目录，获得更好兼容性")
                    }
                    .padding(viewPadding) // 统一的内边距
                }

                // 权限管理
                GroupBox(label: Label("权限管理", systemImage: "lock.shield").font(.headline).padding(.top, sectionSpacing).padding(.bottom, sectionSpacing)) {
                    HStack(spacing: contentSpacing) {
                        Label("辅助功能权限", systemImage: "hand.raised")
                        Capsule()
                            .fill(appState.checkAccessibilityPermissionsStatus() ? Color.green : Color.red)
                            .frame(width: 48, height: 20)
                            .overlay(
                                Text(appState.checkAccessibilityPermissionsStatus() ? "已授权" : "未授权")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                        Spacer()
                        Button {
                            requestingPermission = true
                            appState.requestAccessibilityPermissions()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                requestingPermission = false
                            }
                        } label: {
                            Label(requestingPermission ? "已请求..." : "手动申请", systemImage: "person.badge.key")
                                .frame(minWidth: 80)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(requestingPermission)
                        .help("如未弹出系统授权窗口，请手动前往系统设置-隐私-辅助功能添加 TypeSmart。")
                    }
                    .padding(viewPadding) // 统一的内边距
                }

                // 启动设置
                GroupBox(label: Label("启动设置", systemImage: "arrow.triangle.2.circlepath").font(.headline).padding(.top, sectionSpacing).padding(.bottom, sectionSpacing)) {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Toggle(isOn: $appState.launchAtLoginEnabled) {
                            Label("开机自动启动", systemImage: "bolt.fill")
                        }
                        .help("开启后，TypeSmart 会随系统自动启动。")

                        Toggle(isOn: $appState.autoCheckPermissions) {
                            Label("启动时自动检测权限", systemImage: "checkmark.shield")
                        }
                        .help("每次启动时自动检测并申请辅助功能权限，确保功能正常。")
                    }
                    .padding(viewPadding) // 统一的内边距
                }

                // 帮助与反馈
                GroupBox(label: Label("帮助与反馈", systemImage: "questionmark.circle").font(.headline).padding(.top, sectionSpacing).padding(.bottom, sectionSpacing)) {
                    HStack(spacing: contentSpacing) {
                        Link(destination: URL(string: "mailto:sanbuwang@foxmail.com")!) {
                            Label("联系开发者 (sanbuwang@foxmail.com)", systemImage: "envelope")
                        }
                        Link(destination: URL(string: "https://wangww.online")!) {
                            Label("访问官网", systemImage: "safari")
                        }
                    }
                    .padding(viewPadding) // 统一的内边距
                }
            }
            .padding(viewPadding)
        }
        .frame(minWidth: 400, minHeight: 700)
        .onAppear {
            _ = appState.checkAccessibilityPermissionsStatus()
        }
        .sheet(isPresented: $showMoveAppSheet) {
            MoveAppSheetView(showSheet: $showMoveAppSheet)
        }
    }

    private func moveAppToApplicationsFolder() {
        let appPath = Bundle.main.bundlePath
        let destPath = "/Applications/" + (appPath as NSString).lastPathComponent
        let fileManager = FileManager.default
        let appURL = URL(fileURLWithPath: appPath)
        let destURL = URL(fileURLWithPath: destPath)
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
            // 权限不足时自动打开 Finder 让用户手动拖动
            NSWorkspace.shared.activateFileViewerSelecting([appURL, destURL])
            let alert = NSAlert()
            alert.messageText = "移动失败"
            alert.informativeText = "无法自动移动到 /Applications，请手动将 TypeSmart 拖动到应用程序文件夹。\n错误信息：\(error.localizedDescription)"
            alert.runModal()
        }
    }
}

struct MoveAppSheetView: View {
    @Binding var showSheet: Bool
    var body: some View {
        VStack(spacing: 24) {
            Text("将 TypeSmart 拖动到应用程序文件夹")
                .font(.title2)
                .bold()
            if let icon = NSApp.applicationIconImage {
                DraggableImageView(image: icon)
                    .frame(width: 96, height: 96)
                    .cornerRadius(20)
                    .shadow(radius: 8)
            }
            Text("1. 请在访达中打开“应用程序”文件夹\n2. 将上方 TypeSmart 图标拖动到“应用程序”窗口\n3. 拖拽完成后可从应用程序文件夹重新启动 TypeSmart")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
            Button("打开“应用程序”文件夹") {
                let url = URL(fileURLWithPath: "/Applications")
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            Button("完成") {
                showSheet = false
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 340)
        .background(AlwaysOnTopWindow())
    }
}

struct DraggableImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView(image: image)
        imageView.unregisterDraggedTypes()
        imageView.registerForDraggedTypes([.fileURL])
        imageView.addGestureRecognizer(NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.startDragging)))
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(image: image)
    }

    class Coordinator: NSObject, NSDraggingSource, NSFilePromiseProviderDelegate {
        let image: NSImage

        init(image: NSImage) {
            self.image = image
        }

        @objc func startDragging(sender: NSGestureRecognizer) {
            guard let imageView = sender.view as? NSImageView else { return }
            let filePromise = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
            let draggingItem = NSDraggingItem(pasteboardWriter: filePromise)
            draggingItem.setDraggingFrame(imageView.bounds, contents: image)
            imageView.beginDraggingSession(with: [draggingItem], event: NSApp.currentEvent!, source: self)
        }

        func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
            return "TypeSmartAppIcon.png"
        }

        func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
            if let tiffData = image.tiffRepresentation {
                do {
                    try tiffData.write(to: url)
                    completionHandler(nil)
                } catch {
                    completionHandler(error)
                }
            }
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            return .copy
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            // Handle end of dragging if needed
        }
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
