//
//  ollama_guiApp.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI
import SwiftData

@main
struct ollama_guiApp: App {
    // 添加 OllamaService 实例
    private let ollamaService = OllamaService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(ollamaService) // 添加为环境对象
        }
        .modelContainer(createModelContainer())
        .windowStyle(.hiddenTitleBar)
    }
    
    // 创建一个可靠的 ModelContainer
    private func createModelContainer() -> ModelContainer {
        let schema = Schema([
            OllamaChat.self,
            OllamaMessage.self,
            OllamaModel.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema)
        
        do {
            return try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            // 处理错误
            print("初始化 ModelContainer 失败: \(error)")
            
            // 尝试使用内存模式作为备选方案
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: inMemoryConfig)
            } catch {
                // 如果还是失败，使用空容器
                fatalError("无法创建 ModelContainer：\(error)")
            }
        }
    }
}
