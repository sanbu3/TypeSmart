import Foundation

/// 表示应用之间切换输入法的记录
struct SwitchRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    let timestamp: Date
    let fromAppID: String
    let toAppID: String
    let fromInputSourceID: String
    let toInputSourceID: String
    let isSuccessful: Bool
    
    static func == (lhs: SwitchRecord, rhs: SwitchRecord) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 用于统计和管理所有切换记录
class SwitchRecordManager: ObservableObject {
    static let shared = SwitchRecordManager()
    private let userDefaultsKey = "switchRecords"
    private let maxRecordsToStore = 1000 // 最多存储1000条记录
    
    @Published var records: [SwitchRecord] = []
    
    private init() {
        loadRecords()
    }
    
    func addRecord(fromAppID: String, toAppID: String, 
                   fromInputSourceID: String, toInputSourceID: String, 
                   isSuccessful: Bool) {
        let record = SwitchRecord(timestamp: Date(),
                                  fromAppID: fromAppID,
                                  toAppID: toAppID,
                                  fromInputSourceID: fromInputSourceID,
                                  toInputSourceID: toInputSourceID,
                                  isSuccessful: isSuccessful)
        
        records.append(record)
        
        // 如果记录数超过最大限制，删除最旧的记录
        if records.count > maxRecordsToStore {
            records.removeFirst(records.count - maxRecordsToStore)
        }
        
        saveRecords()
    }
    
    func clearRecords() {
        records.removeAll()
        saveRecords()
    }
    
    // 按应用ID分组统计切换次数
    func getAppSwitchCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        
        for record in records where record.isSuccessful {
            let key = record.toAppID
            counts[key, default: 0] += 1
        }
        
        return counts
    }
    
    // 按时间段统计切换次数（按小时）
    func getHourlySwitchCounts(for days: Int = 7) -> [(hour: Int, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        
        var hourlyCounts = Array(repeating: 0, count: 24)
        
        for record in records where record.isSuccessful && record.timestamp >= startDate {
            let hour = calendar.component(.hour, from: record.timestamp)
            hourlyCounts[hour] += 1
        }
        
        return Array(0..<24).map { (hour: $0, count: hourlyCounts[$0]) }
    }
    
    // 获取过去N天每天的切换次数
    func getDailySwitchCounts(for days: Int = 30) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(date: Date, count: Int)] = []
        
        for day in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -day, to: now) {
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let count = records.filter { 
                    $0.isSuccessful && 
                    $0.timestamp >= startOfDay && 
                    $0.timestamp < endOfDay 
                }.count
                
                result.append((date: startOfDay, count: count))
            }
        }
        
        return result.reversed()
    }
    
    // 获取常用应用对之间的切换次数
    func getCommonAppSwitchPairs(limit: Int = 10) -> [(fromApp: String, toApp: String, count: Int)] {
        var pairCounts: [String: Int] = [:]
        
        for record in records where record.isSuccessful {
            let key = "\(record.fromAppID)|\(record.toAppID)"
            pairCounts[key, default: 0] += 1
        }
        
        let sortedPairs = pairCounts.sorted { $0.value > $1.value }
        
        return sortedPairs.prefix(limit).map { key, count in
            let components = key.split(separator: "|")
            return (fromApp: String(components[0]), toApp: String(components[1]), count: count)
        }
    }
    
    // MARK: - 持久化存储
    
    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        
        do {
            records = try JSONDecoder().decode([SwitchRecord].self, from: data)
            print("[SwitchRecordManager] 加载了 \(records.count) 条记录")
        } catch {
            print("[SwitchRecordManager] 加载记录失败: \(error)")
        }
    }
    
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("[SwitchRecordManager] 保存了 \(records.count) 条记录")
        } catch {
            print("[SwitchRecordManager] 保存记录失败: \(error)")
        }
    }
}