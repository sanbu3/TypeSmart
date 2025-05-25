import Foundation
import SwiftUI
import os.log

// 简化版本的日志管理器
class SimpleLogManager: ObservableObject {
    static let shared = SimpleLogManager()
    
    private let logger = Logger(subsystem: "online.wangww.TypeSmart", category: "SimpleLog")
    @Published var recentLogs: [String] = []
    private let maxLogs = 100
    
    private init() {
        addLog("应用启动", category: "App")
    }
    
    func addLog(_ message: String, category: String = "General") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = "\(timestamp) [\(category)] \(message)"
        
        DispatchQueue.main.async {
            self.recentLogs.append(logEntry)
            if self.recentLogs.count > self.maxLogs {
                self.recentLogs.removeFirst()
            }
        }
        
        // 输出到系统控制台
        logger.info("\(category): \(message)")
        
        #if DEBUG
        print("📝 \(logEntry)")
        #endif
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.recentLogs.removeAll()
        }
        addLog("日志已清除", category: "System")
    }
    
    func exportLogs() -> String {
        var output = "TypeSmart 日志导出\n"
        output += "导出时间: \(Date())\n"
        output += "=".repeating(50) + "\n\n"
        
        for log in recentLogs {
            output += log + "\n"
        }
        
        return output
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
