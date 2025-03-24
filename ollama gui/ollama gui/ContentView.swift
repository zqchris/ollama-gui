//
//  ContentView.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .chats
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    enum Tab {
        case chats, models, settings
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            selectedDetailView
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    // 侧边栏
    private var sidebar: some View {
        List(selection: $selectedTab) {
            NavigationLink(value: Tab.chats) {
                Label("对话", systemImage: "bubble.left.and.bubble.right")
            }
            
            NavigationLink(value: Tab.models) {
                Label("模型", systemImage: "cpu")
            }
            
            NavigationLink(value: Tab.settings) {
                Label("设置", systemImage: "gear")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Ollama GUI")
    }
    
    // 主内容视图
    private var selectedDetailView: some View {
        NavigationStack {
            switch selectedTab {
            case .chats:
                ChatListView()
            case .models:
                ModelListView()
            case .settings:
                SettingsView()
            }
        }
    }
}

// 预览
#Preview {
    ContentView()
        .modelContainer(for: [OllamaChat.self, OllamaMessage.self, OllamaModel.self], inMemory: true)
}
