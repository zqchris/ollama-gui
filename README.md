# Ollama GUI

一个优雅的 macOS 原生 Ollama 客户端，使用 SwiftUI 构建。

## 功能特点

- 🎨 原生 macOS 界面设计
- 💬 流畅的对话体验
- 🖼️ 支持图片输入（适用于多模态模型）
- 🌙 深色模式支持
- ⌨️ 快捷键支持
- 💾 自动保存对话历史
- 📤 支持导出/导入对话记录
- 🔄 实时响应

## 系统要求

- macOS 14.0 或更高版本
- [Ollama](https://ollama.ai) 已安装并运行

## 安装

1. 从 Release 页面下载最新版本
2. 将应用拖入应用程序文件夹
3. 启动应用

## 使用方法

1. 确保 Ollama 服务已在本地运行（默认地址：http://localhost:11434）
2. 启动 Ollama GUI
3. 选择要使用的模型
4. 开始对话

## 快捷键

- `⌘ + Return` - 发送消息
- `⌘ + I` - 插入图片
- `Delete` - 删除已选择的图片

## 开发

### 环境要求

- Xcode 15.0 或更高版本
- Swift 5.9 或更高版本
- macOS 14.0 SDK

### 构建步骤

1. 克隆仓库
```bash
git clone https://github.com/zqchris/ollama-gui.git
cd ollama-gui
```

2. 使用 Xcode 打开项目
```bash
open "ollama gui.xcodeproj"
```

3. 构建并运行项目

## 贡献

欢迎提交 Pull Request 或创建 Issue！

## 许可证

MIT License 