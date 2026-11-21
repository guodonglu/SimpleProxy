import SwiftUI
import AppKit

// MARK: - Design System Tokens for macOS 26/27 (Liquid Glass & HIG)
public struct WhistTheme {
    // Single Accent Color (沉静高亮天青靛蓝 #1E70F0)
    public static let accent = Color(red: 0.12, green: 0.46, blue: 0.96)
    public static let accentSubtle = Color(red: 0.12, green: 0.46, blue: 0.96).opacity(0.12)

    // Semantic Status Colors
    public static let activeGreen = Color(red: 0.16, green: 0.75, blue: 0.42)
    public static let warningAmber = Color(red: 0.96, green: 0.60, blue: 0.15)
    public static let errorRed = Color(red: 0.94, green: 0.28, blue: 0.28)

    // Semantic Gray Scale
    public static var labelPrimary: Color { Color.primary }
    public static var labelSecondary: Color { Color.secondary }
    public static var labelTertiary: Color { Color(nsColor: .tertiaryLabelColor) }
    public static var separator: Color { Color(nsColor: .separatorColor).opacity(0.4) }
    public static var cardBackground: Color { Color(nsColor: .controlBackgroundColor).opacity(0.65) }
    public static var cardBorder: Color { Color.primary.opacity(0.08) }
    public static var pillBackground: Color { Color.primary.opacity(0.05) }

    // Squircles & Radius (Apple Continuous)
    public static let cardRadius: CGFloat = 10
    public static let buttonRadius: CGFloat = 8
    public static let pillRadius: CGFloat = 9999

    // Traffic Lights Safety Margin
    public static let trafficLightsMargin: CGFloat = 78
}

// MARK: - Visual Effect Blur View (AppKit Wrapper for pure Vibrancy)
public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .windowBackground
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active

    public init(
        material: NSVisualEffectView.Material = .windowBackground,
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

// MARK: - Glass Card Modifier (Luminous Apple Liquid Glass)
public struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    public var cornerRadius: CGFloat = WhistTheme.cardRadius
    public var isHighlighted: Bool = false

    private var isLight: Bool {
        colorScheme == .light
    }

    private var cardFillColor: Color {
        if isHighlighted {
            return isLight ? WhistTheme.accent.opacity(0.08) : WhistTheme.accent.opacity(0.20)
        } else {
            return isLight ? Color.white.opacity(0.88) : Color(nsColor: .controlBackgroundColor).opacity(0.55)
        }
    }

    private var cardBaseColor: Color {
        isLight ? Color.white.opacity(0.45) : Color.black.opacity(0.25)
    }

    private var cardStrokeColor: Color {
        if isHighlighted {
            return WhistTheme.accent.opacity(0.45)
        } else {
            return isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
        }
    }

    private var cardShadowColor: Color {
        isLight ? Color.black.opacity(0.035) : Color.black.opacity(0.25)
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(cardFillColor)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(cardBaseColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(cardStrokeColor, lineWidth: 0.75)
            )
            .shadow(
                color: cardShadowColor,
                radius: isLight ? 4 : 8,
                x: 0,
                y: isLight ? 1.5 : 3
            )
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = WhistTheme.cardRadius, isHighlighted: Bool = false) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}
