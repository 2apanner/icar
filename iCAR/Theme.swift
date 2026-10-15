import SwiftUI

/// BMW BimmerCode / BimmerLink Inspired Clean Automotive Design System
enum Theme {
    // Clean System Backgrounds (No Muddy Gold / No Clutter)
    static let canvas = Color(red: 0x0E / 255.0, green: 0x10 / 255.0, blue: 0x15 / 255.0)
    static let surface = Color(red: 0x18 / 255.0, green: 0x1A / 255.0, blue: 0x22 / 255.0)
    static let surfaceElevated = Color(red: 0x22 / 255.0, green: 0x25 / 255.0, blue: 0x30 / 255.0)
    static let surfaceBorder = Color(red: 0x28 / 255.0, green: 0x2C / 255.0, blue: 0x37 / 255.0)
    
    // Signature BMW Precision Blue (Clean, Professional, Non-Crowded)
    static let accent = Color(red: 0x1C / 255.0, green: 0x69 / 255.0, blue: 0xD4 / 255.0)
    static let accentSubtle = Color(red: 0x1C / 255.0, green: 0x69 / 255.0, blue: 0xD4 / 255.0).opacity(0.12)
    
    // Status Indicators
    static let nominal = Color(red: 0x34 / 255.0, green: 0xC7 / 255.0, blue: 0x59 / 255.0)   // System Green
    static let warning = Color(red: 0xFF / 255.0, green: 0x95 / 255.0, blue: 0x00 / 255.0)   // Amber
    static let critical = Color(red: 0xFF / 255.0, green: 0x3B / 255.0, blue: 0x30 / 255.0)  // Crimson Red
    
    // Clean Typography
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0x8E / 255.0, green: 0x92 / 255.0, blue: 0x9E / 255.0)
    static let textMuted = Color(red: 0x63 / 255.0, green: 0x67 / 255.0, blue: 0x73 / 255.0)
    
    // Legacy color alias for smooth transition
    static let champagne = accent
    static let champagneSubtle = accentSubtle
    
    // Apple Smooth Spring
    static let appleSpring = Animation.spring(response: 0.32, dampingFraction: 0.82)
}

struct BimmerCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
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
                    .stroke(Theme.surfaceBorder, lineWidth: 1)
            )
    }
}

extension View {
    func bimmerCard(cornerRadius: CGFloat = 14, padding: CGFloat = 16) -> some View {
        modifier(BimmerCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
    
    func frostedCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(BimmerCardModifier(cornerRadius: cornerRadius, padding: 16))
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
