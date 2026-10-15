import SwiftUI

/// Apple Human Interface Guidelines (HIG) Automotive Dark Mode Design System
enum Theme {
    // True OLED Deep Black Canvas
    static let canvas = Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0C / 255.0)
    
    // Apple Secondary & Tertiary System Surfaces with Glass Transparency
    static let surface = Color(red: 0x16 / 255.0, green: 0x17 / 255.0, blue: 0x1D / 255.0)
    static let surfaceElevated = Color(red: 0x20 / 255.0, green: 0x22 / 255.0, blue: 0x2B / 255.0)
    static let surfaceGlass = Color.white.opacity(0.06)
    static let surfaceBorder = Color.white.opacity(0.10)
    
    // Specular Highlight Gradients (Apple Glass Specularity)
    static let glassBorderGradient = LinearGradient(
        colors: [Color.white.opacity(0.18), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Curated Automotive Palette (Preserves Night Vision)
    // Apple Warm Gold / Champagne Accent
    static let champagne = Color(red: 0xDF / 255.0, green: 0xB8 / 255.0, blue: 0x76 / 255.0)
    static let champagneSubtle = Color(red: 0xDF / 255.0, green: 0xB8 / 255.0, blue: 0x76 / 255.0).opacity(0.15)
    
    // Apple System Status Colors
    static let nominal = Color(red: 0x30 / 255.0, green: 0xD1 / 255.0, blue: 0x58 / 255.0)   // Apple Green
    static let warning = Color(red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x0A / 255.0)   // Apple Orange/Amber
    static let critical = Color(red: 0xFF / 255.0, green: 0x45 / 255.0, blue: 0x3A / 255.0)  // Apple Red
    
    // Apple Typography Labels
    static let textPrimary = Color(red: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF7 / 255.0)
    static let textSecondary = Color(red: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0)
    static let textMuted = Color(red: 0x63 / 255.0, green: 0x63 / 255.0, blue: 0x66 / 255.0)
    
    // Apple Spring Curves
    static let appleSpring = Animation.spring(response: 0.36, dampingFraction: 0.78)
}

struct AppleCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderColor: Color = Theme.surfaceBorder
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.glassBorderGradient, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

struct AppleGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.glassBorderGradient, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func frostedCard(cornerRadius: CGFloat = 20, borderColor: Color = Theme.surfaceBorder) -> some View {
        modifier(AppleCardModifier(cornerRadius: cornerRadius, borderColor: borderColor))
    }
    
    func appleGlassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(AppleGlassCardModifier(cornerRadius: cornerRadius))
    }
    
    func appleHapticImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func appleHapticSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
