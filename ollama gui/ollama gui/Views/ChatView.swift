//
//  ChatView.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI
import SwiftData
import AppKit
import OSLog

struct ChatView: View {
    private let logger = Logger(subsystem: "zkyo.ollama-gui", category: "ChatView")
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var ollamaService: OllamaService
    @Bindable var chat: OllamaChat
    
    @State private var messageText = ""
    @State private var isGenerating = false
    @State private var currentResponse = ""
    @State private var scrollToResponse = false
    @State private var selectedImage: NSImage? = nil
    @State private var showingImagePicker = false
    @State private var errorMessage: String? = nil
    @State private var showingError = false
    
    @State private var pendingMessages: [OllamaMessage] = []
    
    @Query private var models: [OllamaModel]
    
    private static let sequenceLock = NSLock()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 重要改变：使用稳定的排序方法并强制计算当前消息列表
                        let sortedMessages = getSortedMessages()
                        
                        // 使用索引作为额外的稳定标识符
                        ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                            MessageView(
                                message: message,
                                isGenerating: isGenerating && message.id == sortedMessages.last?.id,
                                currentResponse: message.id == sortedMessages.last?.id ? currentResponse : ""
                            )
                            // 使用复合ID作为视图标识符，确保消息不会错位
                            .id("\(index)_\(message.id)")
                        }
                        
                        // 底部锚点用于滚动
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: chat.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: currentResponse) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // 输入区域
            inputAreaView
        }
        .navigationTitle(chat.title)
        .alert("错误", isPresented: $showingError) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }
    
    // 添加一个稳定的消息排序函数
    private func getSortedMessages() -> [OllamaMessage] {
        // 首先获取消息的快照，避免在排序过程中被修改
        let messagesSnapshot = Array(chat.messages)
        
        // 多级排序保证稳定性
        return messagesSnapshot.sorted { first, second in
            // 首先按序列号排序
            if first.sequence != second.sequence {
                return first.sequence < second.sequence
            }
            
            // 序列号相同则按时间戳排序
            if first.timestamp != second.timestamp {
                return first.timestamp < second.timestamp
            }
            
            // 时间戳也相同（极罕见）则按ID排序
            return first.id < second.id
        }
    }
    
    // 改进的输入区域
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            if let image = selectedImage {
                HStack {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: UIConstants.imagePreviewHeight)
                        .cornerRadius(UIConstants.imageCornerRadius)
                        .shadow(
                            color: Color.black.opacity(UIConstants.shadowOpacity),
                            radius: UIConstants.shadowRadius,
                            x: 0,
                            y: UIConstants.shadowOffset
                        )
                    
                    Button {
                        selectedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: UIConstants.messageFontSize))
                            .foregroundColor(.gray)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.delete, modifiers: [])
                    
                    Spacer()
                }
                .padding(.horizontal, UIConstants.messagePadding)
                .padding(.top, UIConstants.messageSpacing)
            }
            
            Divider()
                .background(AppColors.separatorColor)
            
            HStack(alignment: .bottom, spacing: UIConstants.messageSpacing) {
                // 附件按钮
                Button {
                    showImagePicker()
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: UIConstants.messageFontSize))
                        .foregroundColor(selectedImage == nil ? AppColors.disabledContent : AppColors.accentBackground)
                        .frame(width: UIConstants.attachmentButtonSize, height: UIConstants.attachmentButtonSize)
                        .background(AppColors.inputBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("添加图片")
                .keyboardShortcut("i", modifiers: [.command])
                
                // 改进的输入框
                ZStack(alignment: .bottomTrailing) {
                    BorderlessTextField(
                        text: $messageText,
                        placeholder: "输入消息...",
                        isEnabled: !isGenerating,
                        onSubmit: sendMessage
                    )
                    .padding(EdgeInsets(
                        top: UIConstants.inputFieldPadding,
                        leading: UIConstants.inputFieldPadding,
                        bottom: UIConstants.inputFieldPadding,
                        trailing: UIConstants.attachmentButtonSize + UIConstants.inputFieldPadding
                    ))
                    .frame(minHeight: UIConstants.inputFieldMinHeight, maxHeight: UIConstants.inputFieldMaxHeight)
                    .background(
                        RoundedRectangle(cornerRadius: UIConstants.inputFieldCornerRadius)
                            .fill(AppColors.inputBackground)
                            .shadow(
                                color: Color.black.opacity(UIConstants.shadowOpacity),
                                radius: UIConstants.shadowRadius,
                                x: 0,
                                y: UIConstants.shadowOffset
                            )
                    )
                    
                    // 发送按钮整合到输入框内
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                            .font(.system(size: UIConstants.attachmentButtonSize * 0.7))
                            .foregroundColor(messageText.isEmpty && !isGenerating ?
                                AppColors.disabledContent : AppColors.accentBackground)
                            .frame(width: UIConstants.attachmentButtonSize, height: UIConstants.attachmentButtonSize)
                    }
                    .disabled(messageText.isEmpty && !isGenerating)
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .padding(.trailing, UIConstants.messageSpacing * 1.5)
                    .padding(.bottom, UIConstants.messageSpacing)
                }
            }
            .padding(.horizontal, UIConstants.messagePadding)
            .padding(.vertical, UIConstants.messagePadding * 0.8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    private func showImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.selectedImage = image
                    }
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func processImage(_ image: NSImage) -> String? {
        autoreleasepool {
            let maxDimension: CGFloat = 2048
            let size = image.size
            var newSize = size
            
            if size.width > maxDimension || size.height > maxDimension {
                let ratio = size.width / size.height
                if ratio > 1 {
                    newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
                } else {
                    newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
                }
            }
            
            // 创建新的图片并设置尺寸
            let resizedImage = NSImage(size: newSize)
            resizedImage.size = newSize
            
            // 创建位图表示
            guard let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(newSize.width),
                pixelsHigh: Int(newSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                logger.error("Failed to create bitmap representation")
                return nil
            }
            
            // 设置绘图上下文
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            
            guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
                logger.error("Failed to create graphics context")
                return nil
            }
            
            NSGraphicsContext.current = context
            
            // 绘制图片
            image.draw(in: NSRect(origin: .zero, size: newSize),
                      from: NSRect(origin: .zero, size: size),
                      operation: .copy,
                      fraction: 1.0)
            
            // 转换为 PNG 数据
            guard let imageData = bitmapRep.representation(using: .png, properties: [:]) else {
                logger.error("Failed to create PNG data")
                return nil
            }
            
            // 检查大小限制
            if imageData.count > 10 * 1024 * 1024 {
                logger.warning("Image size exceeds limit: \(imageData.count) bytes")
                return nil
            }
            
            return imageData.base64EncodedString()
        }
    }
    
    private func getNextSequenceNumber() -> Int {
        ChatView.sequenceLock.lock()
        defer { ChatView.sequenceLock.unlock() }
        let currentMaxSequence = chat.messages.map { $0.sequence }.max() ?? 0
        return currentMaxSequence + 1
    }
    
    private func sendMessage() {
        if isGenerating {
            ollamaService.cancel()
            isGenerating = false
            return
        }
        
        guard !messageText.isEmpty || selectedImage != nil else { return }
        
        // 消息准备
        let content = messageText
        let currentImage = selectedImage
        messageText = ""
        selectedImage = nil
        
        // 检查是否是支持图片的模型
        let supportedImageModels = ["llava", "bakllava", "gemma", "mixtral", "mistral", "solar"]
        let modelId = chat.modelId.lowercased()
        let isImageSupported = supportedImageModels.contains { modelId.contains($0.lowercased()) }
        
        if currentImage != nil && !isImageSupported {
            showError("当前模型不支持图片功能，请使用支持多模态的模型")
            return
        }
        
        // 处理图片
        var images: [String]? = nil
        var imageDataForMessage: String? = nil
        
        if let image = currentImage {
            guard let base64Image = processImage(image) else {
                showError("图片处理失败")
                return
            }
            images = [base64Image]
            imageDataForMessage = base64Image
        }
        
        // 防止重复发送
        guard !isGenerating else { return }
        
        // 使用线程安全的方式获取序列号
        let userSequence = getNextSequenceNumber()
        let assistantSequence = getNextSequenceNumber()
        
        // 创建消息
        let userMessage = OllamaMessage(role: OllamaMessageRole.user, content: content, imageData: imageDataForMessage, sequence: userSequence)
        let assistantMessage = OllamaMessage(role: OllamaMessageRole.assistant, content: "生成中...", sequence: assistantSequence)
        
        // 设置状态
        isGenerating = true
        currentResponse = ""
        
        // 同步添加消息
        DispatchQueue.main.async {
            // 先添加到数据库
            modelContext.insert(userMessage)
            modelContext.insert(assistantMessage)
            
            // 然后添加到聊天记录
            chat.messages.append(userMessage)
            chat.messages.append(assistantMessage)
            chat.updatedAt = Date()
            
            try? modelContext.save()
        }
        
        // 构建并发送消息
        let messagePayload = OllamaMessagePayload(role: "user", content: content, images: images)
        
        Task {
            do {
                var accumulatedContent = ""
                
                try await ollamaService.sendMessage(
                    [messagePayload],
                    modelName: chat.modelId,
                    onMessageUpdate: { newContent in
                        guard !newContent.isEmpty else { return }
                        DispatchQueue.main.async {
                            // 在主线程更新消息内容
                            let index = chat.messages.firstIndex { $0.id == assistantMessage.id }
                            if let index = index {
                                accumulatedContent += newContent
                                chat.messages[index].content = accumulatedContent
                                currentResponse = accumulatedContent
                            }
                        }
                    },
                    onCompleted: { fullContent in
                        DispatchQueue.main.async {
                            let index = chat.messages.firstIndex { $0.id == assistantMessage.id }
                            if let index = index {
                                chat.messages[index].content = fullContent
                                try? modelContext.save()
                                isGenerating = false
                            }
                        }
                    }
                )
            } catch {
                DispatchQueue.main.async {
                    // 出错时删除助手消息
                    modelContext.delete(assistantMessage)
                    chat.messages.removeAll { $0.id == assistantMessage.id }
                    isGenerating = false
                    
                    if error.localizedDescription.contains("Connection refused") {
                        showError("无法连接到 Ollama 服务，请确保服务已启动")
                    } else {
                        showError("发送消息失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// 消息气泡视图 - 完全重写为更简单的实现
struct MessageView: View {
    let message: OllamaMessage
    let isGenerating: Bool
    let currentResponse: String
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.roleString == "assistant" {
                messageContent
                    .frame(maxWidth: UIConstants.maxMessageWidth, alignment: .leading)
                Spacer(minLength: UIConstants.maxMessageWidth / 3)
            } else {
                Spacer(minLength: UIConstants.maxMessageWidth / 3)
                messageContent
                    .frame(maxWidth: UIConstants.maxMessageWidth, alignment: .trailing)
            }
        }
        .padding(.horizontal, UIConstants.messagePadding)
        .padding(.vertical, UIConstants.messageSpacing / 2)
    }
    
    private var messageContent: some View {
        VStack(alignment: message.roleString == "user" ? .trailing : .leading, spacing: UIConstants.messageSpacing) {
            // 先显示图片（如果有）
            if let imageData = message.imageData,
               let data = Data(base64Encoded: imageData),
               let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIConstants.imageMaxDimension)
                    .cornerRadius(UIConstants.imageCornerRadius)
                    .shadow(
                        color: Color.black.opacity(UIConstants.shadowOpacity),
                        radius: UIConstants.shadowRadius,
                        x: 0,
                        y: UIConstants.shadowOffset
                    )
            }
            
            // 文本内容
            Text(message.content)
                .font(.system(size: UIConstants.messageFontSize))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(UIConstants.messageTextPadding)
                .background(
                    RoundedRectangle(cornerRadius: UIConstants.messageCornerRadius)
                        .fill(message.roleString == "user" ? 
                            AppColors.userMessageBackground : 
                            AppColors.assistantMessageBackground)
                        .shadow(
                            color: Color.black.opacity(UIConstants.shadowOpacity),
                            radius: UIConstants.shadowRadius,
                            x: 0,
                            y: UIConstants.shadowOffset
                        )
                )
                .foregroundColor(message.roleString == "user" ? .white : .primary)
                .opacity(isGenerating && message.content == "生成中..." ? 0.7 : 1.0)
        }
    }
}

// 添加到UIConstants
extension UIConstants {
    static let maxMessageWidth: CGFloat = 500
}

// 自定义无边框TextField
struct BorderlessTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    var onSubmit: (() -> Void)?
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: UIConstants.inputFontSize)
        textField.cell?.wraps = true
        textField.cell?.isScrollable = true
        textField.maximumNumberOfLines = 5
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.isEnabled = isEnabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BorderlessTextField
        
        init(_ parent: BorderlessTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // 回车键按下时触发提交回调
                if !parent.text.isEmpty {
                    parent.onSubmit?()
                }
                return true
            }
            return false
        }
    }
} 