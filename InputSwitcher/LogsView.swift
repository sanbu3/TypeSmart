import SwiftUI
import UniformTypeIdentifiers

struct LogsView: View {
    @ObservedObject var logManager = SimpleLogManager.shared
    @State private var showExportSheet = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("运行日志")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: {
                    showExportSheet = true
                }) {
                    Label("导出日志", systemImage: "square.and.arrow.up")
                }
                .help("导出全部日志内容，便于反馈问题时上传给开发者。")
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logManager.recentLogs, id: \ .self) { log in
                        Text(log)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.vertical, 1)
                    }
                }
            }
        }
        .padding()
        .fileExporter(isPresented: $showExportSheet, document: LogExportDocument(logs: logManager.exportLogs()), contentType: .plainText, defaultFilename: "TypeSmart-logs.txt") { result in
            // 可选：处理导出结果
        }
    }
}

struct LogExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var logs: String
    init(logs: String) { self.logs = logs }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents, let str = String(data: data, encoding: .utf8) {
            logs = str
        } else {
            logs = ""
        }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = logs.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}
