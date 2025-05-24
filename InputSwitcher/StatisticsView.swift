import SwiftUI
import Charts
import Cocoa
import Foundation

struct StatisticsView: View {
    // 使用环境对象
    @EnvironmentObject var appState: AppState
    private let recordManager = SwitchRecordManager.shared
    
    // 选择时间段
    @State private var selectedTimeFrame: TimeFrame = .week
    
    // 状态
    @State private var totalSwitches: Int = 0
    @State private var successfulSwitches: Int = 0
    @State private var failedSwitches: Int = 0
    @State private var topApps: [AppSwitchCount] = []
    @State private var dailyCounts: [DailySwitchCount] = []
    @State private var hourlyCounts: [HourlySwitchCount] = []
    @State private var commonPairs: [AppSwitchPair] = []
    
    // 统一的视图内边距
    private let viewPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 20
    private let contentSpacing: CGFloat = 16
    
    enum TimeFrame: String, CaseIterable, Identifiable {
        case day = "今天"
        case week = "本周"
        case month = "本月"
        case year = "今年"
        case all = "全部"
        
        var id: String { self.rawValue }
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .year: return 365
            case .all: return 3650 // 10年，实际上就是全部
            }
        }
    }
    
    struct AppSwitchCount: Identifiable {
        let id: String // appID
        let name: String
        let count: Int
        let icon: NSImage?
    }
    
    struct DailySwitchCount: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }
    
    struct HourlySwitchCount: Identifiable {
        let id = UUID()
        let hour: Int
        let count: Int
        
        var formattedHour: String {
            return "\(hour):00"
        }
    }
    
    struct AppSwitchPair: Identifiable {
        let id = UUID()
        let fromAppName: String
        let toAppName: String
        let count: Int
        let fromIcon: NSImage?
        let toIcon: NSImage?
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                // 标题和时间选择
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("使用统计")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        Picker("时间范围", selection: $selectedTimeFrame) {
                            ForEach(TimeFrame.allCases) { timeFrame in
                                Text(timeFrame.rawValue).tag(timeFrame)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedTimeFrame) { oldValue, newValue in
                            updateStatistics()
                        }
                    }
                    
                    Text("查看输入法切换的使用情况和统计数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 统计卡片
                HStack(spacing: contentSpacing) {
                    statisticsCard(
                        title: "总切换次数",
                        value: "\(totalSwitches)",
                        systemImage: "arrow.triangle.swap",
                        color: .blue
                    )
                    
                    statisticsCard(
                        title: "成功切换",
                        value: "\(successfulSwitches)",
                        systemImage: "checkmark.circle",
                        color: .green
                    )
                    
                    if totalSwitches > 0 {
                        statisticsCard(
                            title: "成功率",
                            value: String(format: "%.1f%%", Double(successfulSwitches) / Double(totalSwitches) * 100),
                            systemImage: "percent",
                            color: .orange
                        )
                    }
                }
                
                // 如果没有数据，显示空状态
                if totalSwitches == 0 {
                    GroupBox {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("暂无统计数据")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("开始使用 InputSwitcher 后会自动收集统计数据")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .padding(viewPadding)
        }
        .onAppear {
            updateStatistics()
        }
    }
    
    private func statisticsCard(title: String, value: String, systemImage: String, color: Color) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(contentSpacing)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func noDataView() -> some View {
        Text("暂无数据")
            .foregroundColor(.secondary)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
    }
    
    // 辅助方法：计算最大计数值，并增加1做为图表上限
    private func getMaxCount<T>(_ items: [T]) -> Int where T: Identifiable {
        let maxCount: Int
        if let max = items.max(by: { 
            if let item1 = $0 as? DailySwitchCount, let item2 = $1 as? DailySwitchCount {
                return item1.count < item2.count
            } else if let item1 = $0 as? HourlySwitchCount, let item2 = $1 as? HourlySwitchCount {
                return item1.count < item2.count
            }
            return false
        }) {
            if let dailyItem = max as? DailySwitchCount {
                maxCount = dailyItem.count
            } else if let hourlyItem = max as? HourlySwitchCount {
                maxCount = hourlyItem.count
            } else {
                maxCount = 10 // 默认值
            }
        } else {
            maxCount = 10 // 默认值
        }
        
        return maxCount + 1 // 增加1作为上限
    }
    
    private func updateStatistics() {
        // 过滤时间
        let days = selectedTimeFrame.days
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        
        // 过滤符合时间范围的记录
        let filteredRecords = recordManager.records.filter { $0.timestamp >= startDate }
        
        // 计算基本统计数据
        totalSwitches = filteredRecords.count
        successfulSwitches = filteredRecords.filter { $0.isSuccessful }.count
        failedSwitches = totalSwitches - successfulSwitches
        
        // 更新每日统计
        let rawDailyCounts = recordManager.getDailySwitchCounts(for: selectedTimeFrame == .day ? 2 : days) // 如果是今天，至少显示2天
        dailyCounts = rawDailyCounts.map { DailySwitchCount(date: $0.date, count: $0.count) }
        
        // 更新小时分布
        let rawHourlyCounts = recordManager.getHourlySwitchCounts(for: days)
        hourlyCounts = rawHourlyCounts.map { HourlySwitchCount(hour: $0.hour, count: $0.count) }
        
        // 更新应用排行
        let appCounts = recordManager.getAppSwitchCounts()
        topApps = appCounts.map { appID, count in
            let appInfo = appState.discoveredApplications.first { $0.id == appID }
            return AppSwitchCount(
                id: appID,
                name: appInfo?.name ?? appID,
                count: count,
                icon: appInfo?.icon
            )
        }.sorted { $0.count > $1.count }
        
        // 更新应用对统计
        let rawCommonPairs = recordManager.getCommonAppSwitchPairs(limit: 10)
        commonPairs = rawCommonPairs.map { fromAppID, toAppID, count in
            let fromAppInfo = appState.discoveredApplications.first { $0.id == fromAppID }
            let toAppInfo = appState.discoveredApplications.first { $0.id == toAppID }
            
            return AppSwitchPair(
                fromAppName: fromAppInfo?.name ?? fromAppID,
                toAppName: toAppInfo?.name ?? toAppID,
                count: count,
                fromIcon: fromAppInfo?.icon,
                toIcon: toAppInfo?.icon
            )
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(AppState.shared)
}
