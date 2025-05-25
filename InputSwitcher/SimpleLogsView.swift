import SwiftUI

struct SimpleLogsView: View {
    @StateObject private var logManager = SimpleLogManager.shared
    @State private var searchText = ""
    @State private var showingExportSheet = false
    @State private var exportedContent = ""
    @State private var showingClearAlert = false
    
    private let viewPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 20
    private let contentSpacing: CGFloat = 16
    
    var filteredLogs: [String] {
        if searchText.isEmpty {
            return logManager.recentLogs
        } else {
            return logManager.recentLogs.filter { log in
                log.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // 页面标题
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("日志记录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 8) {
                        Button("导出日志") {
                            exportLogs()
                        }
                        .buttonStyle(.bordered)
                        Button("清除日志", role: .destructive) {
                            showingClearAlert = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Text("查看应用运行日志和诊断信息")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 统计信息
            GroupBox {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    Label("日志统计", systemImage: "chart.bar.doc.horizontal")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("总日志数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(logManager.recentLogs.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.green)
                                Text("筛选结果")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(filteredLogs.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                }
                .padding(contentSpacing)
            }
            
            // 搜索过滤器
            GroupBox {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    Label("搜索过滤", systemImage: "magnifyingglass")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("搜索日志内容...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        
                        if !searchText.isEmpty {
                            Button("清除") {
                                searchText = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(contentSpacing)
            }
            
            // 日志列表
            GroupBox {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    HStack {
                        Label("日志条目", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("显示 \(filteredLogs.count) 条记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if filteredLogs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(searchText.isEmpty ? "暂无日志记录" : "没有找到匹配的日志")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(searchText.isEmpty ? "应用运行时会在这里显示日志" : "尝试调整搜索条件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(filteredLogs.reversed().enumerated()), id: \.offset) { index, log in
                                    HStack {
                                        Text(log)
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                }
                .padding(contentSpacing)
            }
        }
        .padding(viewPadding)
        .alert("清除日志", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                logManager.clearLogs()
            }
        } message: {
            Text("确定要清除所有日志记录吗？此操作无法撤销。")
        }
        // sheet 展示导出内容
        .sheet(isPresented: $showingExportSheet) {
            NavigationView {
                ScrollView {
                    Text(exportedContent)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle("导出的日志")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("完成") {
                            showingExportSheet = false
                        }
                    }
                }
            }
        }
    }
    
    private func exportLogs() {
        exportedContent = logManager.exportLogs()
        showingExportSheet = true
    }
}
