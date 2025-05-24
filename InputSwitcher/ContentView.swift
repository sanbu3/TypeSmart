import SwiftUI
import InputMethodKit
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @ObservedObject var appState = AppState.shared
    
    // For NavigationSplitView
    @State private var selectedSidebarItem: SidebarNavigationItem = .rules
    
    // State for the rule editing UI
    @State private var selectedDiscoveredAppID: String? = nil
    @State private var selectedInputSourceID: String = ""
    
    // Updated to use InputSourceInfo
    @State private var availableInputSources: [InputSourceInfo] = []
    @State private var isAppPickerPresented: Bool = false
    @State private var availableAppsForPicker: [AppInfo] = []
    
    // 应用选择器状态
    @State private var isElegantAppPickerPresented: Bool = false
    @State private var elegantAppPickerApps: [AppInfo] = []
    @State private var elegantAppPickerSearch: String = ""

    enum SidebarNavigationItem: String, CaseIterable, Hashable, Identifiable {
        case rules = "应用规则"
        case statistics = "使用统计"
        case general = "通用"
        case about = "关于"

        var id: String { self.rawValue }

        var systemImage: String {
            switch self {
            case .rules: return "list.star"
            case .statistics: return "chart.bar"
            case .general: return "gear"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                ForEach(SidebarNavigationItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.systemImage).tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            switch selectedSidebarItem {
            case .rules:
                rulesManagementView()
            case .statistics:
                StatisticsView()
                    .environmentObject(appState)
            case .general:
                GeneralSettingsView()
                    .environmentObject(appState)
            case .about:
                AboutUsView()
            }
        }
        .onAppear {
            if appState.discoveredApplications.isEmpty {
                appState.discoverApplications()
            }
            loadInputSources()

            DispatchQueue.main.async {
                if self.selectedDiscoveredAppID == nil, let firstAppID = self.appState.discoveredApplications.first?.id {
                    self.selectedDiscoveredAppID = firstAppID
                }
                if !self.availableInputSources.isEmpty && !self.availableInputSources.contains(where: { $0.id == self.selectedInputSourceID }) {
                    if let chineseSource = self.availableInputSources.first(where: { InputSourceManager.shared.getLanguageMode(for: $0.id) == .chinese }) {
                        self.selectedInputSourceID = chineseSource.id
                    } else if let englishSource = self.availableInputSources.first(where: { InputSourceManager.shared.getLanguageMode(for: $0.id) == .english }) {
                        self.selectedInputSourceID = englishSource.id
                    } else if let firstSource = self.availableInputSources.first {
                        self.selectedInputSourceID = firstSource.id
                    }
                }
            }
        }
    }

    // 统一的视图内边距
    private let viewPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 20
    private let contentSpacing: CGFloat = 16

    // MARK: - Rules Management View
    @ViewBuilder
    private func rulesManagementView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // 页面标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("应用规则设置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("根据不同应用自动切换输入法。请确保已授权辅助功能权限。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 当前规则列表
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("当前规则", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if appState.appInputSourceMap.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.stack.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("暂无规则")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("请添加应用规则来自动切换输入法")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(appState.appInputSourceMap.keys.sorted(), id: \.self) { appIdentifier in
                                    RuleRowView(
                                        appIdentifier: appIdentifier,
                                        appInfo: appState.discoveredApplications.first(where: { $0.id == appIdentifier }),
                                        inputSourceID: appState.appInputSourceMap[appIdentifier] ?? "",
                                        availableInputSources: availableInputSources,
                                        selectedDiscoveredAppID: $selectedDiscoveredAppID,
                                        selectedInputSourceID: $selectedInputSourceID,
                                        onDelete: { deleteRule(appIdentifier: $0) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(contentSpacing)
                }
                
                // 添加/修改规则区
                GroupBox {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Label("添加规则", systemImage: "plus.app")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: contentSpacing) {
                            HStack(alignment: .top, spacing: 20) {
                                // 应用选择
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("应用", systemImage: "app")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 8) {
                                        TextField("请输入 Bundle ID", text: Binding(
                                            get: { selectedDiscoveredAppID ?? "" },
                                            set: { newValue in selectedDiscoveredAppID = newValue.isEmpty ? nil : newValue }
                                        ))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(minWidth: 200)
                                        
                                        Menu {
                                            Button(action: {
                                                elegantAppPickerApps = discoverAllApplications()
                                                elegantAppPickerSearch = ""
                                                isElegantAppPickerPresented = true
                                            }) {
                                                Label("从应用列表选择", systemImage: "list.bullet")
                                            }
                                            
                                            Button(action: showNativeAppPicker) {
                                                Label("浏览文件夹选择", systemImage: "folder")
                                            }
                                        } label: {
                                            Image(systemName: "plus.app")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.bordered)
                                        .help("选择应用")
                                        
                                        Button(action: showBundleIDHelp) {
                                            Image(systemName: "questionmark.circle")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.borderless)
                                        .help("如何获取 Bundle ID？")
                                    }
                                }
                                
                                // 输入法选择
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("输入法", systemImage: "keyboard")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("选择输入法", selection: $selectedInputSourceID) {
                                        ForEach(availableInputSources, id: \.id) { inputSource in
                                            Text(inputSource.localizedName).tag(inputSource.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(minWidth: 150)
                                }
                            }
                            
                            // 操作按钮
                            HStack {
                                Button("刷新应用列表") {
                                    appState.discoverApplications()
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                if let appID = selectedDiscoveredAppID, appState.appInputSourceMap[appID] != nil {
                                    Button("删除规则", role: .destructive) {
                                        deleteSelectedRule()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Button(action: addOrUpdateRule) {
                                    Label(
                                        appState.appInputSourceMap[selectedDiscoveredAppID ?? ""] != nil ? "更新规则" : "添加规则",
                                        systemImage: appState.appInputSourceMap[selectedDiscoveredAppID ?? ""] != nil ? "arrow.triangle.2.circlepath" : "plus"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(selectedDiscoveredAppID == nil || selectedInputSourceID.isEmpty)
                            }
                        }
                    }
                    .padding(contentSpacing)
                }
            }
            .padding(viewPadding)
        }
        .sheet(isPresented: $isElegantAppPickerPresented) {
            ModernAppPickerSheet(
                allApps: elegantAppPickerApps,
                searchText: $elegantAppPickerSearch,
                onSelect: { app in
                    if !appState.discoveredApplications.contains(app) {
                        appState.discoveredApplications.append(app)
                    }
                    selectedDiscoveredAppID = app.id
                    isElegantAppPickerPresented = false
                },
                onCancel: {
                    isElegantAppPickerPresented = false
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Helper Functions
    private func showBundleIDHelp() {
        let alert = NSAlert()
        alert.messageText = "如何获取 Bundle ID？"
        alert.informativeText = """
        方法 1: 在访达中选中应用，按下 Command+I 查看简介，复制"信息"中的 Bundle Identifier。
        
        方法 2: 在终端输入：
        mdls -name kMDItemCFBundleIdentifier /Applications/应用名.app
        
        方法 3: 使用本应用的应用选择器，会自动填入正确的 Bundle ID。
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func loadInputSources() {
        print("[ContentView] loadInputSources: Starting to load input sources...")
        let sources = InputSourceManager.shared.getInputSources()
        
        print("[ContentView] loadInputSources: Found \(sources.count) sources from InputSourceManager.")

        self.availableInputSources = sources.sorted { (s1, s2) -> Bool in
            let mode1 = InputSourceManager.shared.getLanguageMode(for: s1.id)
            let mode2 = InputSourceManager.shared.getLanguageMode(for: s2.id)

            if mode1 == .chinese && mode2 != .chinese { return true }
            if mode1 != .chinese && mode2 == .chinese { return false }
            if mode1 == .english && mode2 != .english { return true }
            if mode1 != .english && mode2 == .english { return false }
            
            return s1.localizedName.lowercased() < s2.localizedName.lowercased()
        }
        
        print("[ContentView] loadInputSources: Loaded and sorted \(self.availableInputSources.count) displayable input sources.")
        
        if !self.availableInputSources.isEmpty {
            if selectedInputSourceID.isEmpty || !self.availableInputSources.contains(where: {$0.id == selectedInputSourceID}) {
                if let chineseSource = self.availableInputSources.first(where: { InputSourceManager.shared.getLanguageMode(for: $0.id) == .chinese }) {
                    selectedInputSourceID = chineseSource.id
                    print("[ContentView] loadInputSources: Defaulted selectedInputSourceID to Chinese: \(chineseSource.id) (\(chineseSource.localizedName)).")
                } else if let englishSource = self.availableInputSources.first(where: { InputSourceManager.shared.getLanguageMode(for: $0.id) == .english }) {
                    selectedInputSourceID = englishSource.id
                    print("[ContentView] loadInputSources: Defaulted selectedInputSourceID to English: \(englishSource.id) (\(englishSource.localizedName)).")
                } else if let firstSource = self.availableInputSources.first {
                    selectedInputSourceID = firstSource.id
                    print("[ContentView] loadInputSources: Defaulted selectedInputSourceID to first available: \(firstSource.id) (\(firstSource.localizedName)).")
                }
            } else {
                 print("[ContentView] loadInputSources: Retained existing valid selectedInputSourceID: \(selectedInputSourceID)")
            }
        } else {
            selectedInputSourceID = ""
            print("[ContentView] loadInputSources: No input sources available. Cleared selectedInputSourceID.")
        }
    }

    private func addOrUpdateRule() {
        guard let appIdentifier = selectedDiscoveredAppID, !selectedInputSourceID.isEmpty else {
            print("[ContentView] addOrUpdateRule: App identifier or input source ID is empty. Cannot add/update rule.")
            return
        }

        appState.appInputSourceMap[appIdentifier] = selectedInputSourceID
        let appName = appState.discoveredApplications.first(where: {$0.id == appIdentifier})?.name ?? appIdentifier
        let inputSourceName = availableInputSources.first(where: {$0.id == selectedInputSourceID})?.localizedName ?? selectedInputSourceID
        print("[ContentView] addOrUpdateRule: Rule added/updated for \(appName) (ID: \(appIdentifier)) -> \(inputSourceName) (ID: \(selectedInputSourceID))")
    }

    private func deleteRule(appIdentifier: String) {
        let appName = appState.discoveredApplications.first(where: {$0.id == appIdentifier})?.name ?? appIdentifier
        let inputSourceID = appState.appInputSourceMap[appIdentifier] ?? "N/A"
        let inputSourceName = availableInputSources.first(where: {$0.id == inputSourceID})?.localizedName ?? inputSourceID
        
        appState.appInputSourceMap.removeValue(forKey: appIdentifier)
        print("[ContentView] 删除规则: \(appName) (ID: \(appIdentifier)) 对应输入法 \(inputSourceName) (ID: \(inputSourceID))")
        
        if selectedDiscoveredAppID == appIdentifier {
            selectedDiscoveredAppID = nil
        }
    }
    
    private func deleteSelectedRule() {
        guard let appIdentifier = selectedDiscoveredAppID,
              appState.appInputSourceMap[appIdentifier] != nil else {
            return
        }
        
        deleteRule(appIdentifier: appIdentifier)
        selectedDiscoveredAppID = nil
    }
    
    private func discoverAllApplications() -> [AppInfo] {
        let fm = FileManager.default
        let appDirs = ["/Applications", (fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path)]
        var apps: [AppInfo] = []
        for dir in appDirs {
            if let enumerator = fm.enumerator(atPath: dir) {
                for case let file as String in enumerator {
                    if file.hasSuffix(".app") {
                        let url = URL(fileURLWithPath: dir).appendingPathComponent(file)
                        if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                            let appName = url.deletingPathExtension().lastPathComponent
                            let appInfo = AppInfo(id: bundleID, name: appName, path: url)
                            if !apps.contains(appInfo) {
                                apps.append(appInfo)
                            }
                        }
                    }
                }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Rule Row View
private struct RuleRowView: View {
    let appIdentifier: String
    let appInfo: AppInfo?
    let inputSourceID: String
    let availableInputSources: [InputSourceInfo]
    @Binding var selectedDiscoveredAppID: String?
    @Binding var selectedInputSourceID: String
    let onDelete: (String) -> Void

    var body: some View {
        let appName = appInfo?.name ?? appIdentifier
        let inputSourceName = availableInputSources.first(where: { $0.id == inputSourceID })?.localizedName ?? inputSourceID
        
        HStack(spacing: 12) {
            // App icon and info
            HStack(spacing: 8) {
                if let info = appInfo, let nsIcon = info.icon {
                    Image(nsImage: nsIcon)
                        .resizable()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "questionmark.app.dashed")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(appIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Input source
            Text(inputSourceName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            
            // Actions
            HStack(spacing: 4) {
                Button("编辑") {
                    selectedDiscoveredAppID = appIdentifier
                    selectedInputSourceID = inputSourceID
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    onDelete(appIdentifier)
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(selectedDiscoveredAppID == appIdentifier ? Color.accentColor.opacity(0.1) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedDiscoveredAppID == appIdentifier ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(8)
        .onTapGesture {
            selectedDiscoveredAppID = appIdentifier
            if availableInputSources.contains(where: { $0.id == inputSourceID }) {
                selectedInputSourceID = inputSourceID
            } else if let first = availableInputSources.first {
                selectedInputSourceID = first.id
            } else {
                selectedInputSourceID = ""
            }
        }
    }
}

// MARK: - Modern App Picker Sheet
private struct ModernAppPickerSheet: View {
    let allApps: [AppInfo]
    @Binding var searchText: String
    let onSelect: (AppInfo) -> Void
    let onCancel: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var filteredApps: [AppInfo] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return allApps
        }
        let lower = searchText.lowercased()
        return allApps.filter { $0.name.lowercased().contains(lower) || $0.id.lowercased().contains(lower) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择应用")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("找到 \(filteredApps.count) 个应用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("取消") {
                    onCancel()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索应用名或 Bundle ID", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // 应用列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredApps, id: \.id) { app in
                        AppRowView(app: app) {
                            onSelect(app)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - App Row View
private struct AppRowView: View {
    let app: AppInfo
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                
                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(app.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.5)
            }
            .padding(12)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAppState = AppState.shared
        
        mockAppState.discoveredApplications = [
            AppInfo(id: "com.apple.safari", name: "Safari", path: URL(fileURLWithPath: "/Applications/Safari.app")),
            AppInfo(id: "com.microsoft.vscode", name: "Visual Studio Code", path: URL(fileURLWithPath: "/Applications/Visual Studio Code.app")),
            AppInfo(id: "com.apple.dt.Xcode", name: "Xcode", path: URL(fileURLWithPath: "/Applications/Xcode.app"))
        ]
        
        mockAppState.appInputSourceMap = [
            "com.apple.safari": "com.apple.keylayout.ABC",
            "com.microsoft.vscode": "com.apple.inputmethod.SCIM.Pinyin"
        ]
        
        return ContentView().environmentObject(mockAppState)
    }
}

// MARK: - Alternative App Selection Methods
extension ContentView {
    private func showNativeAppPicker() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择应用程序"
        openPanel.message = "请选择要添加规则的应用程序"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = false
        openPanel.allowedContentTypes = [UTType.applicationBundle]
        
        // 设置初始目录为 /Applications
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        // 设置初始目录
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        openPanel.begin { response in
            if response == .OK, let selectedURL = openPanel.url {
                DispatchQueue.main.async {
                    self.handleSelectedApp(from: selectedURL)
                }
            }
        }
    }
    
    private func handleSelectedApp(from url: URL) {
        guard url.pathExtension == "app" else {
            showAlert(title: "无效选择", message: "请选择一个 .app 文件")
            return
        }
        
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            showAlert(title: "无法获取信息", message: "无法获取应用的 Bundle ID")
            return
        }
        
        let appName = url.deletingPathExtension().lastPathComponent
        let appInfo = AppInfo(id: bundleID, name: appName, path: url)
        
        // 添加到已发现的应用列表
        if !appState.discoveredApplications.contains(appInfo) {
            appState.discoveredApplications.append(appInfo)
        }
        
        // 设置选中的应用
        selectedDiscoveredAppID = bundleID
        
        print("选择应用: \(appName) (\(bundleID))")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
