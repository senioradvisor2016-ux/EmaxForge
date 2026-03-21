import SwiftUI

/// EMULOTION by Vintage Voltage — Design System
/// Inspired by vintagevoltage.se darkwave aesthetic
enum Theme {
    
    // MARK: - Primary Colors
    
    /// Neon magenta — primary accent (buttons, badges, highlights)
    static let accent = Color(red: 0.72, green: 0.28, blue: 1.0)       // #B847FF
    
    /// Deep purple — secondary accent
    static let accentDeep = Color(red: 0.55, green: 0.18, blue: 0.79)  // #8B2FC9
    
    /// Warm amber — secondary highlight (SCSI badges, warnings)
    static let amber = Color(red: 0.91, green: 0.66, blue: 0.22)       // #E8A838
    
    /// Neon cyan — tertiary (info, zones, slots)
    static let cyan = Color(red: 0.35, green: 0.85, blue: 0.95)        // #59D9F2
    
    // MARK: - Backgrounds
    
    /// Deep black background
    static let bgDeep = Color(red: 0.04, green: 0.04, blue: 0.06)      // #0A0A0F
    
    /// Slightly lighter surface
    static let bgSurface = Color(red: 0.08, green: 0.07, blue: 0.11)   // #14121C
    
    /// Card/panel background
    static let bgCard = Color(red: 0.11, green: 0.10, blue: 0.15)      // #1C1926
    
    /// Elevated surface
    static let bgElevated = Color(red: 0.14, green: 0.13, blue: 0.19)  // #24212F
    
    // MARK: - Text
    
    static let textPrimary = Color(red: 0.91, green: 0.91, blue: 0.91) // #E8E8E8
    static let textSecondary = Color(red: 0.55, green: 0.52, blue: 0.62) // #8C859E
    static let textTertiary = Color(red: 0.35, green: 0.33, blue: 0.42) // #59546B
    
    // MARK: - Semantic
    
    static let success = Color(red: 0.30, green: 0.85, blue: 0.50)     // #4DD980
    static let warning = amber
    static let danger = Color(red: 0.95, green: 0.30, blue: 0.35)      // #F24D59
    
    // MARK: - Gradients
    
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let amberGradient = LinearGradient(
        colors: [amber, Color(red: 0.85, green: 0.50, blue: 0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let darkGradient = LinearGradient(
        colors: [bgSurface, bgDeep],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Glow effects
    
    static func glow(_ color: Color, radius: CGFloat = 10) -> some View {
        color.opacity(0.4).blur(radius: radius)
    }
    
    // MARK: - Design System
    
    /// Spacing system (4pt grid)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    /// Typography system
    enum Typography {
        static let title = Font.system(size: 20, weight: .bold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 14, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let footnote = Font.system(size: 11, weight: .regular)
    }
    
    /// Elevation & Shadows
    enum Elevation {
        static let card = Shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        static let modal = Shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        static let tooltip = Shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        static let button = Shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
    
    /// Animation timings
    enum Animation {
        static let quick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let gentle = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.9)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

extension View {
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}
