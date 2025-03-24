//
//  OllamaService.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import Foundation
import OSLog

class OllamaService: ObservableObject {
    private let logger = Logger(subsystem: "zkyo.ollama-gui", category: "OllamaService")
    private let baseURL: String
    private var task: Task<Void, Error>?
    
    // 添加网络超时时间
    private let timeoutInterval: TimeInterval = 30
    
    // 扩展错误类型
    enum OllamaError: LocalizedError {
        case invalidURL
        case decodingError
        case serverError
        case connectionFailed
        case timeout
        case rateLimited
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的服务器地址"
            case .decodingError:
                return "数据解析错误"
            case .serverError:
                return "服务器错误"
            case .connectionFailed:
                return "连接失败，请检查 Ollama 服务是否运行"
            case .timeout:
                return "请求超时"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            }
        }
    }
    
    init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }
    
    private func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        return request
    }
    
    private func handleNetworkError(_ error: Error) -> OllamaError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .connectionFailed
            default:
                return .networkError(error)
            }
        }
        return .networkError(error)
    }
    
    /// 测试与Ollama服务器的连接
    func testConnection() async -> (success: Bool, message: String) {
        do {
            logger.info("Testing connection: \(self.baseURL)/version")
            let url = URL(string: "\(baseURL)/version")!
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("HTTP status code: \(httpResponse.statusCode)")
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let responseString = String(data: data, encoding: .utf8) {
                        logger.info("Server response: \(responseString)")
                        return (true, "连接成功: \(responseString)")
                    }
                    return (true, "连接成功")
                } else {
                    return (false, "服务器返回错误: \(httpResponse.statusCode)")
                }
            }
            return (false, "无效的响应")
        } catch {
            logger.error("Connection test failed: \(error.localizedDescription)")
            return (false, "连接失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取可用的模型列表
    func getModels() async throws -> [ModelInfo] {
        logger.info("Requesting URL: \(self.baseURL)/tags")
        guard let url = URL(string: "\(baseURL)/tags") else {
            throw OllamaError.invalidURL
        }
        
        let request = createRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("Response status code: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    break
                case 429:
                    throw OllamaError.rateLimited
                default:
                    throw OllamaError.serverError
                }
            }
            
            do {
                let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
                return modelsResponse.models
            } catch {
                logger.error("Decoding error: \(error)")
                throw OllamaError.decodingError
            }
        } catch {
            logger.error("Network error: \(error)")
            throw handleNetworkError(error)
        }
    }
    
    /// 获取正在进行的模型下载列表
    func getModelDownloadStatus() async throws -> ProgressResponse? {
        let url = URL(string: "\(baseURL)/show?detailed=true")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ProgressResponse.self, from: data)
    }
    
    /// 下载一个新模型
    func downloadModel(name: String) async throws {
        struct DownloadRequest: Codable {
            let name: String
        }
        
        let url = URL(string: "\(baseURL)/pull")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = DownloadRequest(name: name)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            throw OllamaError.serverError
        }
    }
    
    /// 使用流式API发送聊天消息
    func sendMessage(
        _ messages: [OllamaMessagePayload],
        modelName: String,
        onMessageUpdate: @escaping (String) -> Void,
        onCompleted: @escaping (String) -> Void
    ) async throws {
        // 取消之前的任务
        task?.cancel()
        
        let url = URL(string: "\(baseURL)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = ChatRequest(
            model: modelName,
            messages: messages,
            stream: true
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(chatRequest)
        
        task = Task {
            var fullContent = ""
            let (stream, _) = try await URLSession.shared.bytes(for: request)
            
            for try await line in stream.lines {
                try Task.checkCancellation()
                
                guard let data = line.data(using: .utf8),
                      let response = try? JSONDecoder().decode(ChatResponse.self, from: data),
                      let content = response.message?.content else {
                    continue
                }
                
                fullContent += content
                onMessageUpdate(content)
                
                if response.done == true {
                    onCompleted(fullContent)
                    break
                }
            }
        }
        
        try await task?.value
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
    
    deinit {
        cancel()
    }
}

// MARK: - 数据模型
struct ModelsResponse: Codable {
    let models: [ModelInfo]
}

struct ModelInfo: Codable, Identifiable {
    let name: String
    let size: Int64
    let modified_at: String
    let details: ModelDetails?
    
    var id: String { name }
}

struct ModelDetails: Codable {
    let format: String?
    let family: String?
    let parameter_size: String?
    let quantization_level: String?
}

struct OllamaMessagePayload: Codable {
    let role: String
    let content: String
    let images: [String]?
    
    init(role: String, content: String, images: [String]? = nil) {
        self.role = role
        self.content = content
        self.images = images
    }
}

struct ChatRequest: Codable {
    let model: String
    let messages: [OllamaMessagePayload]
    let stream: Bool
    let options: [String: String]?
    
    init(model: String, messages: [OllamaMessagePayload], stream: Bool = true, options: [String: String]? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.options = options
    }
}

struct ChatResponse: Codable {
    let message: ChatMessage?
    let done: Bool?
}

struct ChatMessage: Codable {
    let role: String?
    let content: String?
}

struct ProgressResponse: Codable {
    let status: String?
    let digest: String?
    let total: Int64?
    let completed: Int64?
} 