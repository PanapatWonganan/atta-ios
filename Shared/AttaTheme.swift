import SwiftUI

extension Color {
    /// 0xRRGGBB hex literal, matching the Android AttaPalette values.
    init(atta hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Raw brand tokens — atta.color.* from the Phase A sheet.
enum AttaPalette {
    static let canvas = Color(atta: 0xF7F4EF)
    static let canvasAlt = Color(atta: 0xEDE6DC)
    static let ink = Color(atta: 0x1C1917)
    static let canvasDark = Color(atta: 0x191517)
    static let inkDark = Color(atta: 0xF2EDE6)

    // One accent per screen. Matte only — never gradiented, never glossed.
    static let champagne = Color(atta: 0xC2A57B)
    static let champagneDeep = Color(atta: 0x8A7550)
    static let sage = Color(atta: 0x9AAE9C)
    static let sageDeep = Color(atta: 0x7E937F)
    static let clay = Color(atta: 0xC99C94)
    static let deepTeal = Color(atta: 0x1F4B47)
    static let plum = Color(atta: 0x5E4C63)
}

/// Mode-resolved surfaces. Dark mode inverts canvas/ink; champagne stays matte on both.
struct AttaColors {
    let canvas: Color
    let canvasAlt: Color
    let ink: Color
    let card: Color
    let onInk: Color
    let isDark: Bool

    func inkAlpha(_ alpha: Double) -> Color { ink.opacity(alpha) }

    static let light = AttaColors(
        canvas: AttaPalette.canvas,
        canvasAlt: AttaPalette.canvasAlt,
        ink: AttaPalette.ink,
        card: .white,
        onInk: AttaPalette.inkDark,
        isDark: false
    )

    static let dark = AttaColors(
        canvas: AttaPalette.canvasDark,
        canvasAlt: AttaPalette.inkDark.opacity(0.08),
        ink: AttaPalette.inkDark,
        card: AttaPalette.inkDark.opacity(0.06),
        onInk: AttaPalette.ink,
        isDark: true
    )

    static func resolve(dark: Bool) -> AttaColors { dark ? .dark : .light }
}

private struct AttaColorsKey: EnvironmentKey {
    static let defaultValue = AttaColors.light
}

extension EnvironmentValues {
    /// Screens read `@Environment(\.atta)` — the Compose `Atta.colors` equivalent.
    var atta: AttaColors {
        get { self[AttaColorsKey.self] }
        set { self[AttaColorsKey.self] = newValue }
    }
}

/// Spacing on an 8pt base. Whitespace is the product: screen gutter never below md.
enum AttaDimens {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 48
    static let xxl: CGFloat = 64

    static let radiusCard: CGFloat = 20
    static let radiusButton: CGFloat = 14
    static let radiusChip: CGFloat = 10

    static let touchTarget: CGFloat = 48
}

/// atta.motion.* — breath-paced. No springs anywhere; overshoot breaks the register.
enum AttaMotion {
    static let screenEnter: Double = 0.48
    static let cardSwipe: Double = 0.56
    static let gradientDrift: Double = 10.0
    static let breathIn: Double = 4.0
    static let breathOut: Double = 6.0
    static let tap: Double = 0.12
    static let tapScale: CGFloat = 0.98

    static let easeInOut = Animation.timingCurve(0.42, 0, 0.58, 1, duration: screenEnter)

    static func ease(_ duration: Double) -> Animation {
        .timingCurve(0.42, 0, 0.58, 1, duration: duration)
    }
}
