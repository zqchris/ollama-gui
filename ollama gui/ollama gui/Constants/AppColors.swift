import SwiftUI

enum AppColors {
    static var userMessageBackground: Color {
        Color(light: NSColor(red: 0.0, green: 0.47, blue: 1.0, alpha: 1.0),
              dark: NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0))
    }
    
    static var assistantMessageBackground: Color {
        Color(light: NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
              dark: NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0))
    }
    
    static var inputBackground: Color {
        Color(light: NSColor.controlBackgroundColor,
              dark: NSColor(white: 0.2, alpha: 1.0))
    }
    
    static var accentBackground: Color {
        Color.accentColor
    }
    
    static var disabledContent: Color {
        Color(light: NSColor.tertiaryLabelColor,
              dark: NSColor(white: 0.4, alpha: 1.0))
    }
    
    static var separatorColor: Color {
        Color(light: NSColor.separatorColor,
              dark: NSColor(white: 0.3, alpha: 1.0))
    }
}

extension Color {
    init(light: NSColor, dark: NSColor) {
        self.init(NSColor(name: nil) { appearance in
            appearance.name == .darkAqua ? dark : light
        })
    }
} 