//
//  ModelListView.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI
import SwiftData

struct ModelListView: View {
    @ObservedObject private var ollamaService = OllamaService()
    @State private var models: [ModelInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var searchText = ""
    @State private var showDownloadSheet = false
    @State private var isDownloading = false
    @State private var downloadProgress: Float = 0
    @State private var downloadModelName: String = ""
    
    @Environment(\.modelContext) private var modelContext
    @Query private var savedModels: [OllamaModel]
    
    var filteredModels: [ModelInfo] {
        if searchText.isEmpty {
            return models
        } else {
            return models.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            if isLoading && models.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if filteredModels.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("没有找到模型")
                        .font(.headline)
                    
                    if !searchText.isEmpty {
                        Text("尝试其他搜索关键词")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Button("下载模型") {
                            showDownloadSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredModels) { model in
                    modelRow(for: model)
                }
            }
        }
        .navigationTitle("可用模型")
        .searchable(text: $searchText, prompt: "搜索模型")
        .refreshable {
            await loadModels()
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showDownloadSheet = true
                } label: {
                    Label("下载", systemImage: "arrow.down.circle")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await loadModels()
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showDownloadSheet) {
            downloadModelSheet
        }
        .task {
            if models.isEmpty {
                await loadModels()
            }
        }
    }
    
    // 模型下载表单
    private var downloadModelSheet: some View {
        NavigationStack {
            Form {
                Section("下载新模型") {
                    TextField("模型名称 (例如: llama3.8b)", text: $downloadModelName)
                    
                    Button {
                        downloadModel()
                    } label: {
                        if isDownloading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("下载中... \(Int(downloadProgress * 100))%")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("开始下载")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .disabled(downloadModelName.isEmpty || isDownloading)
                }
                
                Section("热门模型") {
                    suggestedModelButton("llama3-8b")
                    suggestedModelButton("llama3-70b")
                    suggestedModelButton("deepseek-coder")
                    suggestedModelButton("codellama")
                    suggestedModelButton("mistral-7b")
                }
            }
            .disabled(isDownloading)
            .navigationTitle("下载模型")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showDownloadSheet = false
                    }
                    .disabled(isDownloading)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // 推荐模型按钮
    private func suggestedModelButton(_ modelName: String) -> some View {
        Button {
            downloadModelName = modelName
        } label: {
            HStack {
                Text(modelName)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 单个模型行视图
    private func modelRow(for model: ModelInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let details = model.details {
                        if let family = details.family {
                            Text(family)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let parameters = details.parameter_size {
                            Text(parameters)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(ByteCountFormatter.string(fromByteCount: model.size, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                createNewChat(with: model.name)
            } label: {
                Text("新对话")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // 加载模型列表
    private func loadModels() async {
        isLoading = true
        errorMessage = nil
        
        do {
            models = try await ollamaService.getModels()
            // 更新或创建本地模型数据
            updateLocalModels()
        } catch {
            errorMessage = "无法加载模型: \(error.localizedDescription)"
            showErrorAlert = true
        }
        
        isLoading = false
    }
    
    // 更新本地模型数据
    private func updateLocalModels() {
        for model in models {
            if let existingModel = savedModels.first(where: { $0.id == model.name }) {
                existingModel.name = model.name
                existingModel.isDownloaded = true
                existingModel.size = model.size
                existingModel.updatedAt = Date()
            } else {
                let newModel = OllamaModel(
                    id: model.name,
                    name: model.name,
                    isDownloaded: true,
                    size: model.size
                )
                modelContext.insert(newModel)
            }
        }
    }
    
    // 创建新的聊天会话
    private func createNewChat(with modelName: String) {
        let newChat = OllamaChat(title: "新对话", modelId: modelName)
        modelContext.insert(newChat)
    }
    
    // 下载新模型
    private func downloadModel() {
        guard !downloadModelName.isEmpty else { return }
        
        isDownloading = true
        downloadProgress = 0
        
        Task {
            do {
                try await ollamaService.downloadModel(name: downloadModelName)
                
                // 检查下载进度
                while isDownloading {
                    if let progress = try? await ollamaService.getModelDownloadStatus() {
                        if let total = progress.total, let completed = progress.completed, total > 0 {
                            DispatchQueue.main.async {
                                downloadProgress = Float(completed) / Float(total)
                            }
                        }
                        
                        // 检查是否完成
                        if progress.status == "success" {
                            DispatchQueue.main.async {
                                isDownloading = false
                                showDownloadSheet = false
                                downloadModelName = ""
                                
                                // 刷新模型列表
                                Task {
                                    await loadModels()
                                }
                            }
                            break
                        }
                    }
                    
                    // 暂停一下再检查进度
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                }
            } catch {
                DispatchQueue.main.async {
                    isDownloading = false
                    errorMessage = "下载失败: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
} 