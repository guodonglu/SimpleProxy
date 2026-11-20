import SwiftUI
import AppKit

// MARK: - Design System Tokens for macOS 26/27 (Liquid Glass & HIG)
public struct WhistTheme {
    // Single Accent Color (沉静高亮天青靛蓝)
    public static let accent = Color(red: 0.22, green: 0.52, blue: 0.98)
    public static let accentSubtle = Color(red: 0.22, green: 0.52, blue: 0.98).opacity(0.12)

    // Semantic Status Colors
    public static let activeGreen = Color(red: 0.18, green: 0.78, blue: 0.44)
    public static let warningAmber = Color(red: 0.96, green: 0.62, blue: 0.18)
    public static let errorRed = Color(red: 0.94, green: 0.32, blue: 0.32)

    // Semantic Gray Scale
    public static var labelPrimary: Color { Color.primary }
    public static var labelSecondary: Color { Color.secondary }
    public static var labelTertiary: Color { Color(nsColor: .tertiaryLabelColor) }
    public static var separator: Color { Color(nsColor: .separatorColor).opacity(0.6) }
    public static var cardBackground: Color { Color(nsColor: .controlBackgroundColor).opacity(0.45) }
    public static var cardBorder: Color { Color.primary.opacity(0.06) }
    public static var pillBackground: Color { Color.primary.opacity(0.06) }

    // Squircles & Radius (Apple Continuous)
    public static let cardRadius: CGFloat = 12
    public static let buttonRadius: CGFloat = 8
    public static let pillRadius: CGFloat = 9999

    // Traffic Lights Safety Margin
    public static let trafficLightsMargin: CGFloat = 78
}

// MARK: - Visual Effect Blur View (AppKit Wrapper for pure Vibrancy)
public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .sidebar
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active

    public init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Glass Card Modifier
public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = WhistTheme.cardRadius
    public var isHighlighted: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHighlighted ? WhistTheme.accentSubtle : WhistTheme.cardBackground)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isHighlighted ? WhistTheme.accent.opacity(0.4) : WhistTheme.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = WhistTheme.cardRadius, isHighlighted: Bool = false) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}
