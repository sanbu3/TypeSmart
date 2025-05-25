import Foundation
import os.log

/// 日志级别枚举
enum LogLevel: String, CaseIterable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
}

/// 日志条目结构
struct LogEntry: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: String]?
    let stackTrace: String?
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var formattedMessage: String {
        return "\(formattedTimestamp) [\(level.rawValue)] [\(category)] \(message)"
    }
}

/// 日志管理器
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    // 系统日志
    private let logger = Logger(subsystem: "online.wangww.TypeSmart", category: "LogManager")
    
    // 内存中的日志记录
    @Published var logs: [LogEntry] = []
    
    // 配置
    private let maxLogsInMemory = 500
    private let maxLogsInFile = 2000
    private let userDefaultsKey = "appLogs"
    
    // 文件路径
    private var logFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                 in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TypeSmart")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, 
                                               withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent("app.log")
    }
    
    private init() {
        loadLogs()
        
        // 应用启动日志
        log(.info, category: "App", message: "TypeSmart 应用启动", metadata: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "system": ProcessInfo.processInfo.operatingSystemVersionString,
            "locale": Locale.current.identifier
        ])
    }
    
    // MARK: - 核心日志方法
    
    /// 记录日志
    func log(_ level: LogLevel, 
             category: String, 
             message: String, 
             metadata: [String: String]? = nil,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            stackTrace: level == .error || level == .critical ? "\(file):\(function):\(line)" : nil
        )
        
        // 添加到内存
        DispatchQueue.main.async {
            self.logs.append(entry)
            
            // 限制内存中的日志数量
            if self.logs.count > self.maxLogsInMemory {
                self.logs.removeFirst(self.logs.count - self.maxLogsInMemory)
            }
        }
        
        // 写入系统日志
        logger.log(level: level.osLogType, "\(category): \(message)")
        
        // 异步保存到文件
        Task {
            await saveToFile(entry)
        }
        
        // 控制台输出（调试模式）
        #if DEBUG
        print("\(level.emoji) \(entry.formattedMessage)")
        if let metadata = metadata {
            print("   Metadata: \(metadata)")
        }
        #endif
    }
    
    // MARK: - 便捷方法
    
    func debug(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.debug, category: category, message: message, metadata: metadata)
    }
    
    func info(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.info, category: category, message: message, metadata: metadata)
    }
    
    func warning(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.warning, category: category, message: message, metadata: metadata)
    }
    
    func error(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.error, category: category, message: message, metadata: metadata)
    }
    
    func critical(_ category: String, _ message: String, metadata: [String: String]? = nil) {
        log(.critical, category: category, message: message, metadata: metadata)
    }
    
    // MARK: - 特殊用途日志方法
    
    /// 记录输入法切换
    func logInputSwitch(from: String, to: String, app: String, success: Bool, duration: TimeInterval? = nil) {
        var metadata: [String: String] = [
            "from_input": from,
            "to_input": to,
            "app": app,
            "success": String(success)
        ]
        
        if let duration = duration {
            metadata["duration_ms"] = String(format: "%.2f", duration * 1000)
        }
        
        log(success ? .info : .error, 
            category: "InputSwitch", 
            message: "输入法切换: \(from) → \(to) (应用: \(app))",
            metadata: metadata)
    }
    
    /// 记录应用切换
    func logAppSwitch(from: String?, to: String, hasRule: Bool) {
        log(.info, category: "AppSwitch", message: "应用切换: \(from ?? "unknown") → \(to)", metadata: [
            "from_app": from ?? "unknown",
            "to_app": to,
            "has_rule": String(hasRule)
        ])
    }
    
    /// 记录性能指标
    func logPerformance(operation: String, duration: TimeInterval, metadata: [String: String]? = nil) {
        var allMetadata = metadata ?? [:]
        allMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)
        
        let level: LogLevel = duration > 1.0 ? .warning : .info
        log(level, category: "Performance", message: "操作耗时: \(operation)", metadata: allMetadata)
    }
    
    /// 记录错误
    func logError(_ error: Error, context: String, metadata: [String: String]? = nil) {
        var allMetadata = metadata ?? [:]
        allMetadata["error_type"] = String(describing: type(of: error))
        allMetadata["error_description"] = error.localizedDescription
        
        log(.error, category: "Error", message: "错误发生: \(context)", metadata: allMetadata)
    }
    
    // MARK: - 文件操作
    
    private func saveToFile(_ entry: LogEntry) async {
        do {
            let logLine = entry.formattedMessage + "\n"
            
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                defer { try? fileHandle.close() }
                
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8) ?? Data())
                
                // 检查文件大小，如果太大则轮转
                let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
                if let fileSize = attributes[.size] as? Int, fileSize > 5 * 1024 * 1024 { // 5MB
                    try rotateLogFile()
                }
            } else {
                try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // 文件写入失败，只记录到系统日志
            logger.error("Failed to write log to file: \(error.localizedDescription)")
        }
    }
    
    private func rotateLogFile() throws {
        let oldLogURL = logFileURL.appendingPathExtension("old")
        
        // 删除旧的备份文件
        if FileManager.default.fileExists(atPath: oldLogURL.path) {
            try FileManager.default.removeItem(at: oldLogURL)
        }
        
        // 移动当前日志文件为备份
        try FileManager.default.moveItem(at: logFileURL, to: oldLogURL)
        
        log(.info, category: "LogManager", message: "日志文件轮转完成")
    }
    
    // MARK: - 数据持久化
    
    private func loadLogs() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        
        do {
            let decodedLogs = try JSONDecoder().decode([LogEntry].self, from: data)
            DispatchQueue.main.async {
                self.logs = Array(decodedLogs.suffix(self.maxLogsInMemory))
            }
        } catch {
            logger.error("Failed to load logs from UserDefaults: \(error.localizedDescription)")
        }
    }
    
    private func saveLogs() {
        do {
            let data = try JSONEncoder().encode(Array(logs.suffix(maxLogsInFile)))
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            logger.error("Failed to save logs to UserDefaults: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 数据导出
    
    /// 导出日志数据
    func exportLogs() -> String {
        var output = "TypeSmart 日志导出\n"
        output += "导出时间: \(Date())\n"
        output += "应用版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")\n"
        output += "系统版本: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        output += String(repeating: "=", count: 60) + "\n\n"
        
        // 从文件读取完整日志
        if let fileContent = try? String(contentsOf: logFileURL, encoding: .utf8) {
            output += fileContent
        }
        
        // 添加内存中的最新日志
        output += "\n最新内存日志:\n"
        for log in logs.suffix(50) {
            output += log.formattedMessage + "\n"
            if let metadata = log.metadata {
                output += "  Metadata: \(metadata)\n"
            }
        }
        
        return output
    }
    
    /// 获取统计信息
    func getLogStatistics() -> [String: Any] {
        let levelCounts = Dictionary(grouping: logs, by: { $0.level })
            .mapValues { $0.count }
        
        let categoryCounts = Dictionary(grouping: logs, by: { $0.category })
            .mapValues { $0.count }
        
        return [
            "total_logs": logs.count,
            "level_distribution": levelCounts,
            "category_distribution": categoryCounts,
            "oldest_log": logs.first?.timestamp ?? Date(),
            "newest_log": logs.last?.timestamp ?? Date(),
            "log_file_size": (try? FileManager.default.attributesOfItem(atPath: logFileURL.path)[.size] as? Int) ?? 0
        ]
    }
    
    /// 清除日志
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
        
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        
        // 删除日志文件
        try? FileManager.default.removeItem(at: logFileURL)
        
        log(.info, category: "LogManager", message: "所有日志已清除")
    }
    
    /// 过滤日志
    func filteredLogs(level: LogLevel? = nil, category: String? = nil, searchText: String? = nil) -> [LogEntry] {
        return logs.filter { log in
            if let level = level, log.level != level {
                return false
            }
            
            if let category = category, log.category != category {
                return false
            }
            
            if let searchText = searchText, !searchText.isEmpty {
                return log.message.localizedCaseInsensitiveContains(searchText) ||
                       log.category.localizedCaseInsensitiveContains(searchText)
            }
            
            return true
        }
    }
    
    deinit {
        saveLogs()
    }
}
