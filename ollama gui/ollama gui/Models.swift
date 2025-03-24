//
//  Models.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import Foundation
import SwiftData

enum OllamaMessageRole: String, Codable {
    case system
    case user
    case assistant
}

@Model
final class OllamaChat {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modelId: String
    @Relationship(deleteRule: .cascade) var messages: [OllamaMessage]
    
    init(title: String = "新对话", modelId: String) {
        self.id = UUID().uuidString
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelId = modelId
        self.messages = []
    }
}

@Model
final class OllamaMessage {
    @Attribute(.unique) var id: String
    @Attribute(.externalStorage) var content: String
    @Attribute(.externalStorage) var imageData: String?
    var timestamp: Date
    var sequence: Int
    var roleString: String
    
    var role: OllamaMessageRole {
        get { 
            print("获取 role，原始字符串: \(roleString)")
            return OllamaMessageRole(rawValue: roleString) ?? .user 
        }
        set { 
            print("设置 role: \(newValue.rawValue)")
            roleString = newValue.rawValue 
        }
    }
    
    init(role: OllamaMessageRole, content: String, imageData: String? = nil, sequence: Int = 0) {
        self.id = UUID().uuidString
        self.content = content
        self.imageData = imageData
        self.timestamp = Date()
        self.sequence = sequence
        self.roleString = role.rawValue
        print("创建消息，角色: \(role.rawValue)")
    }
}

@Model
final class OllamaModel {
    @Attribute(.unique) var id: String
    var name: String
    var isDownloaded: Bool
    var size: Int64?
    var updatedAt: Date
    
    init(id: String, name: String, isDownloaded: Bool = false, size: Int64? = nil) {
        self.id = id
        self.name = name
        self.isDownloaded = isDownloaded
        self.size = size
        self.updatedAt = Date()
    }
}
