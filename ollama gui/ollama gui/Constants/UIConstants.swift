import Foundation
import SwiftUI

enum UIConstants {
    // 消息气泡相关
    static let maxMessageWidth: CGFloat = 600
    static let messagePadding: CGFloat = 16
    static let messageCornerRadius: CGFloat = 20
    static let messageSpacing: CGFloat = 12
    static let messageTextPadding: EdgeInsets = EdgeInsets(
        top: 12,
        leading: 16,
        bottom: 12,
        trailing: 16
    )
    
    // 图片相关
    static let imageMaxDimension: CGFloat = 300
    static let imageCornerRadius: CGFloat = 12
    static let imagePreviewHeight: CGFloat = 200
    
    // 输入框相关
    static let inputFieldMinHeight: CGFloat = 44
    static let inputFieldMaxHeight: CGFloat = 120
    static let inputFieldCornerRadius: CGFloat = 22
    static let inputFieldPadding: CGFloat = 16
    
    // 附件按钮相关
    static let attachmentButtonSize: CGFloat = 32
    static let attachmentButtonCornerRadius: CGFloat = 16
    
    // 动画时间
    static let defaultAnimationDuration: Double = 0.2
    
    // 阴影
    static let shadowRadius: CGFloat = 3
    static let shadowOpacity: CGFloat = 0.1
    static let shadowOffset: CGFloat = 1
    
    // 字体大小
    static let messageFontSize: CGFloat = 14
    static let inputFontSize: CGFloat = 14
    static let captionFontSize: CGFloat = 12
    
    // 列表相关
    static let listItemSpacing: CGFloat = 12
    static let listSectionSpacing: CGFloat = 24
} 