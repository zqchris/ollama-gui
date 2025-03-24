# Ollama GUI 编码规则

## 数据模型规则

1. **模型重命名与重构**：
   - 当重命名或更改数据模型类型时，必须使用全局搜索找出所有引用并更新
   - 使用 Find All References 工具（⇧⌘F）搜索所有旧类名的引用
   - 对于数据模型变更，必须同时更新 SwiftData Schema 配置

2. **数据模型一致性**：
   - 所有数据模型类命名应与文件名保持一致
   - 重命名文件时应确保内部类名也一起更新
   - 命名变更后必须重新检查项目编译状态

## UI 组件规则

1. **导航层次结构**：
   - 避免在 NavigationSplitView 内的 detail 视图中嵌套不必要的 NavigationStack
   - 在 NavigationSplitView 使用时，子视图应直接使用 .navigationDestination 修饰符
   - 确保理解 SwiftUI 导航容器的层次关系，避免冗余嵌套
   - 当在 NavigationSplitView 的 detail 中需要导航时，应统一包装在一个 NavigationStack 中

2. **视图层次组织**：
   - 避免过深的视图嵌套，最多不超过 5 层
   - 复杂视图应拆分为多个子视图组件
   - 使用 @ViewBuilder 封装复杂的条件视图

3. **SwiftUI 条件视图一致性**：
   - switch 语句或 if-else 条件中的所有分支必须返回相同类型的视图
   - 当不同分支返回不同类型的视图时，使用 NavigationStack 或 AnyView 封装以保持类型一致性
   - 避免过度使用 AnyView，可能导致性能问题；优先考虑使用 Group 或统一的容器视图
   - 在 ViewBuilder 上下文中（如 body 属性），确保所有条件分支返回一致的视图类型层次

4. **平台特定 API 使用**：
   - 明确区分 iOS 专属和 macOS 专属的 API，避免跨平台误用
   - 不要在 macOS 应用中使用以下 iOS 专属修饰符：
     - `.navigationBarTitleDisplayMode()`（使用 `.navigationTitle()` 替代）
     - `.navigationBarHidden()`
     - `.navigationBarBackButtonHidden()`
   - 不要在 iOS 应用中使用以下 macOS 专属修饰符：
     - `.windowStyle()`
     - `.windowToolbarStyle()`
   - 对于需要跨平台兼容的代码，使用 `#if os(macOS)` 和 `#if os(iOS)` 条件编译
   - 在使用新的 SwiftUI API 前，查阅文档确认其可用平台

5. **颜色系统使用**：
   - macOS 和 iOS 的颜色系统不同，不可互相混用
   - 在 macOS 应用中：
     - 不要使用 UIKit 颜色标识符如 `.systemGray6`、`.tertiarySystemBackground` 等
     - 应使用 `Color(nsColor: .windowBackgroundColor)` 或 `Color(nsColor: .textBackgroundColor)` 等 macOS 原生颜色
     - 或者使用 SwiftUI 内置通用颜色如 `.background`、`.secondary`、`.blue` 等
   - 在跨平台应用中，使用条件编译区分颜色：
     ```swift
     #if os(macOS)
     .background(Color(nsColor: .windowBackgroundColor))
     #else
     .background(Color(uiColor: .systemBackground))
     #endif
     ```
   - **重要**：不要直接扩展 Color 或 ShapeStyle 类型添加静态属性，这可能导致类型不兼容问题
   - 应创建独立的颜色结构体或枚举（如 `AppColors`）来提供应用颜色主题
   - 在视图中使用颜色时要指明完整路径，如 `AppColors.accentBackground`
   - 所有应用颜色定义应集中在 Extensions/ColorExtensions.swift 文件中

6. **扩展使用**：
   - 为通用功能创建扩展，保持代码的可复用性和一致性
   - 所有扩展应放在 Extensions 目录下，按照功能或类型命名（如 ColorExtensions.swift）
   - 扩展应该有清晰的文档注释说明用途
   - 通用属性和方法应通过扩展添加，而不是在每个视图中重复实现
   - 扩展应专注于单一功能，不应包含不相关的方法
   - **警告**：扩展系统类型（如 Color）添加静态属性时，应考虑 SwiftUI 的类型转换和协议一致性问题
   - 对于颜色系统，应使用独立的结构体而非扩展，避免 ShapeStyle 协议兼容性问题

## 错误处理与安全

1. **空值处理**：
   - 使用可选值时必须进行适当的解包处理
   - 对于数据模型关系，务必考虑关系对象为 nil 的情况
   - 使用 guard let 或 if let 进行安全解包

2. **异步操作**：
   - 所有网络或长时间运行的任务必须在 Task 或 async 函数中执行
   - UI 更新必须回到主线程（使用 DispatchQueue.main.async）
   - 提供合适的加载状态指示器和错误提示

3. **变量使用**：
   - 声明的变量必须被使用，未使用的变量应及时移除
   - 局部变量的作用域应尽可能小，避免过早声明变量
   - 使用 `let` 声明不会改变的值，仅在必要时使用 `var`
   - 对于仅用于一次赋值后立即使用的变量，考虑是否可以直接使用表达式

## 项目维护

1. **文件组织**：
   - 按功能模块组织文件夹（Models, Views, Services, Extensions 等）
   - 保持文件夹结构与项目导航一致
   - 移动或重命名文件后确保更新所有引用
   - 新增文件应添加到合适的目录中，遵循现有的命名规范

2. **代码审查清单**：
   - 提交前进行全项目编译检查
   - 确认所有数据模型变更在 Schema 中正确注册
   - 验证 NavigationStack 和 NavigationSplitView 的正确使用
   - 检查所有可能的 nil 值处理
   - 确保所有条件分支返回一致的视图类型
   - 验证所有 UI API 在目标平台上可用
   - 确认使用了正确的颜色系统，并避免在视图修饰符中直接使用自定义扩展的 Color 属性
   - 移除所有未使用的变量和导入
   - 检查是否有可以封装到扩展中的重复代码
   - 确保视图修饰符（如 `.background()`）使用了正确的类型 