import SwiftUI
import Charts

struct StatItem: Identifiable {
    let id = UUID()
    let appName: String
    let switchCount: Int
}

struct StatisticsView: View {
    @ObservedObject var recordManager = SwitchRecordManager.shared
    @ObservedObject var appState = AppState.shared
    @State private var showClearAlert = false

    // 统计数据生成
    private var appSwitchStats: [StatItem] {
        let counts = recordManager.getAppSwitchCounts()
        return counts.map { key, value in
            StatItem(appName: appState.discoveredApplications.first(where: { $0.id == key })?.name ?? key, switchCount: value)
        }
    }
    private var totalSwitches: Int { recordManager.records.count }
    private var successCount: Int { recordManager.records.filter { $0.isSuccessful }.count }
    private var failCount: Int { recordManager.records.filter { !$0.isSuccessful }.count }
    private var commonPairs: [(fromApp: String, toApp: String, count: Int)] { recordManager.getCommonAppSwitchPairs() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("输入法切换统计")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label("清除统计数据", systemImage: "trash")
                    }
                    .help("清空所有输入法切换统计数据")
                    .alert(isPresented: $showClearAlert) {
                        Alert(
                            title: Text("确认清除？"),
                            message: Text("此操作将清空所有输入法切换统计数据，无法恢复。"),
                            primaryButton: .destructive(Text("清除")) {
                                recordManager.clearRecords()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                Divider()
            if totalSwitches > 0 {
                HStack(spacing: 32) {
                    VStack(alignment: .leading) {
                        Text("总切换次数")
                            .font(.caption)
                        Text("\(totalSwitches)")
                            .font(.title3).bold()
                    }
                    VStack(alignment: .leading) {
                        Text("成功")
                            .font(.caption)
                        Text("\(successCount)")
                            .foregroundColor(.green)
                    }
                    VStack(alignment: .leading) {
                        Text("失败")
                            .font(.caption)
                        Text("\(failCount)")
                            .foregroundColor(.red)
                    }
                }
                .padding(.bottom, 8)
                if !appSwitchStats.isEmpty {
                    Chart(appSwitchStats) { item in
                        BarMark(
                            x: .value("应用", item.appName),
                            y: .value("切换次数", item.switchCount)
                        )
                        .foregroundStyle(by: .value("应用", item.appName))
                    }
                    .frame(height: 220)
                    .padding(.vertical)
                }
                if !commonPairs.isEmpty {
                    Text("常用切换对")
                        .font(.headline)
                        .padding(.top, 8)
                    ForEach(Array(commonPairs.enumerated()), id: \.offset) { _, pair in
                        HStack {
                            Text("\(pair.fromApp) → \(pair.toApp)")
                            Spacer()
                            Text("\(pair.count) 次")
                                .foregroundColor(.secondary)
                        }
                    }
                }                } else {
                    Text("暂无统计数据")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

#Preview {
    StatisticsView()
}
