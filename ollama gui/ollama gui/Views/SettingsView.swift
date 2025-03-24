//
//  SettingsView.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("ollamaServerURL") private var ollamaServerURL: String = "http://localhost:11434"
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("enableStreamingResponse") private var enableStreamingResponse: Bool = true
    @Environment(\.modelContext) private var modelContext
    
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var connectionTestResult: String = ""
    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    @State private var backupError: String?
    @State private var showingError = false
    
    @ObservedObject private var ollamaService = OllamaService()
    
    enum ConnectionStatus {
        case unknown, success, failed
        
        var icon: String {
            switch self {
            case .unknown:
                return "questionmark.circle"
            case .success:
                return "checkmark.circle"
            case .failed:
                return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown:
                return .gray
            case .success:
                return .green
            case .failed:
                return .red
            }
        }
    }
    
    var body: some View {
        Form {
            Section("Ollama 服务器") {
                HStack {
                    TextField("服务器地址", text: $ollamaServerURL)
                    
                    Button {
                        testAdvancedConnection()
                    } label: {
                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: connectionStatus.icon)
                                .foregroundColor(connectionStatus.color)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTestingConnection)
                }
                
                // 显示高级测试结果
                if !connectionTestResult.isEmpty {
                    Text(connectionTestResult)
                        .font(.caption)
                        .foregroundColor(connectionTestResult.contains("成功") ? .green : .red)
                        .padding(.top, 4)
                }
                
                Toggle("启用流式响应", isOn: $enableStreamingResponse)
                
                Button("测试连接") {
                    testAdvancedConnection()
                }
                .disabled(isTestingConnection)
            }
            
            Section("界面设置") {
                Toggle("深色模式", isOn: $isDarkMode)
                
                VStack(alignment: .leading) {
                    Text("字体大小: \(Int(fontSize))")
                    
                    Slider(value: $fontSize, in: 12...24, step: 1) {
                        Text("字体大小")
                    }
                }
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Ollama GUI")
                    Spacer()
                    Link("项目主页", destination: URL(string: "https://github.com/yourusername/ollama-gui")!)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Ollama 官方")
                    Spacer()
                    Link("ollama.com", destination: URL(string: "https://ollama.com")!)
                        .foregroundColor(.blue)
                }
            }
            
            Section("数据管理") {
                HStack {
                    Text("备份与恢复")
                    Spacer()
                    Button("导出数据") {
                        exportData()
                    }
                    Button("导入数据") {
                        importData()
                    }
                }
            }
        }
        .navigationTitle("设置")
        .fileExporter(
            isPresented: $showingExportDialog,
            document: BackupDocument(chats: try? modelContext.fetch(FetchDescriptor<OllamaChat>())),
            contentType: .json,
            defaultFilename: "ollama-gui-backup.json"
        ) { result in
            if case .failure(let error) = result {
                backupError = error.localizedDescription
                showingError = true
            }
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                importDataFromURL(url)
            case .failure(let error):
                backupError = error.localizedDescription
                showingError = true
            }
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定") { }
        } message: {
            Text(backupError ?? "未知错误")
        }
    }
    
    private func testConnection() {
        connectionStatus = .unknown
        isTestingConnection = true
        
        Task {
            do {
                let url = URL(string: "\(ollamaServerURL)/api/version")!
                let request = URLRequest(url: url, timeoutInterval: 5)
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        connectionStatus = .success
                        isTestingConnection = false
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                DispatchQueue.main.async {
                    connectionStatus = .failed
                    isTestingConnection = false
                }
            }
        }
    }
    
    // 使用OllamaService的新方法进行高级连接测试
    private func testAdvancedConnection() {
        connectionStatus = .unknown
        isTestingConnection = true
        connectionTestResult = ""
        
        Task {
            let result = await ollamaService.testConnection()
            
            DispatchQueue.main.async {
                connectionStatus = result.success ? .success : .failed
                connectionTestResult = result.message
                isTestingConnection = false
            }
        }
    }
    
    private func exportData() {
        showingExportDialog = true
    }
    
    private func importData() {
        showingImportDialog = true
    }
    
    private func importDataFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let backup = try decoder.decode(BackupData.self, from: data)
            
            // 清除现有数据
            try modelContext.delete(model: OllamaChat.self)
            
            // 导入新数据
            for chat in backup.chats {
                modelContext.insert(chat)
            }
            
            try modelContext.save()
        } catch {
            backupError = error.localizedDescription
            showingError = true
        }
    }
}

// 备份文档类型
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var chats: [OllamaChat]?
    
    init(chats: [OllamaChat]?) {
        self.chats = chats
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let chats = try? JSONDecoder().decode([OllamaChat].self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.chats = chats
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(chats)
        return .init(regularFileWithContents: data)
    }
}

// 备份数据结构
struct BackupData: Codable {
    let version: Int = 1
    let chats: [OllamaChat]
    let timestamp: Date = Date()
} 