//
//  ChatListView.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI
import SwiftData

struct ChatListView: View {
    @Query(sort: \OllamaChat.updatedAt, order: .reverse) private var chats: [OllamaChat]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var ollamaService: OllamaService
    
    @State private var showModelSelection = false
    @State private var searchText = ""
    @State private var selectedChat: OllamaChat?
    
    var filteredChats: [OllamaChat] {
        if searchText.isEmpty {
            return chats
        } else {
            return chats.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        List {
            if chats.isEmpty {
                ContentUnavailableView {
                    Label("没有对话", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("开始新对话，探索 AI 助手的能力")
                } actions: {
                    Button("新建对话") {
                        showModelSelection = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredChats) { chat in
                    NavigationLink(value: chat) {
                        ChatRow(chat: chat)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(chat)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            // 编辑标题，这里简单地改名
                            rename(chat)
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("对话")
        .searchable(text: $searchText, prompt: "搜索对话")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showModelSelection = true
                } label: {
                    Label("新对话", systemImage: "plus")
                }
            }
        }
        .navigationDestination(for: OllamaChat.self) { chat in
            ChatView(ollamaService: ollamaService, chat: chat)
        }
        .sheet(isPresented: $showModelSelection) {
            modelSelectionSheet
        }
    }
    
    // 模型选择表单
    private var modelSelectionSheet: some View {
        NavigationStack {
            ModelListView()
                .navigationTitle("选择模型")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            showModelSelection = false
                        }
                    }
                }
        }
    }
    
    // 删除对话
    private func delete(_ chat: OllamaChat) {
        modelContext.delete(chat)
    }
    
    // 重命名对话
    private func rename(_ chat: OllamaChat) {
        // 这里只是简单地添加一个"(已编辑)"标记
        // 在真实应用中，应该弹出对话框让用户输入新名称
        chat.title += " (已编辑)"
        chat.updatedAt = Date()
    }
}

// 聊天行视图
struct ChatRow: View {
    let chat: OllamaChat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(chat.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                // 模型图标
                Text(chat.modelId)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                // 消息数量
                Text("\(chat.messages.count) 条消息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 最后一条消息预览
            if let lastMessage = chat.messages.last {
                Text(lastMessage.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
    }
} 