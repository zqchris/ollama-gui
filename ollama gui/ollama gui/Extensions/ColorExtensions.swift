//
//  ColorExtensions.swift
//  ollama gui
//
//  Created by Chris Zhang on 3/18/25.
//

import SwiftUI

// 创建自定义颜色方案
struct AppColors {
    /// 聊天消息背景色 - 用户发送的消息
    static var userMessageBackground: Color {
        return Color(red: 0.0, green: 0.478, blue: 1.0)
    }
    
    /// 聊天消息背景色 - AI助手发送的消息
    static var assistantMessageBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        #else
        return Color(uiColor: .systemGray6)
        #endif
    }
    
    /// 用户消息文本颜色
    static var userMessageText: Color {
        return .white
    }
    
    /// 助手消息文本颜色
    static var assistantMessageText: Color {
        #if os(macOS)
        return Color(nsColor: .labelColor)
        #else
        return Color(uiColor: .label)
        #endif
    }
    
    /// 输入框背景色
    static var inputBackground: Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color(uiColor: .tertiarySystemBackground)
        #endif
    }
    
    /// 主题强调色
    static var accentBackground: Color {
        return Color(red: 0.0, green: 0.478, blue: 1.0)
    }
    
    /// 非激活状态或禁用状态的颜色
    static var disabledContent: Color {
        return .gray.opacity(0.6)
    }
    
    /// 卡片背景色
    static var cardBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }
} 