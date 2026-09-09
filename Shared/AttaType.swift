import SwiftUI

/// atta.type.* — Noto Serif Thai for display, IBM Plex Sans Thai for UI.
/// Line heights are generous by design: Thai upper tone marks need >= 1.6x on
/// serif display sizes or they collide with the ascender band above.
enum AttaType {
    static func serif(_ size: CGFloat, _ weight: SerifWeight = .regular) -> Font {
        .custom(weight.postScript, size: size)
    }

    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular) -> Font {
        .custom(weight.postScript, size: size)
    }

    enum SerifWeight {
        case light, regular, medium, semibold
        var postScript: String {
            switch self {
            case .light: "NotoSerifThai-Light"
            case .regular: "NotoSerifThai-Regular"
            case .medium: "NotoSerifThai-Medium"
            case .semibold: "NotoSerifThai-SemiBold"
            }
        }
    }

    enum SansWeight {
        case light, regular, medium, semibold
        var postScript: String {
            switch self {
            case .light: "IBMPlexSansThai-Light"
            case .regular: "IBMPlexSansThai-Regular"
            case .medium: "IBMPlexSansThai-Medium"
            case .semibold: "IBMPlexSansThai-SemiBold"
            }
        }
    }
}

/// Text style presets mirroring Android's AttaType text styles.
/// Usage: `Text(...).atta(.display, colors.ink)`.
enum AttaTextStyle {
    case display     // serif 34/54, -0.2 tracking
    case displaySm   // serif 26/42
    case title       // sans medium 20/32
    case body        // sans 16/27
    case label       // sans medium 13/20, +1.1 tracking
    case caption     // sans 11/18, +0.5 tracking
    case eyebrow     // sans medium 10/16, +2 tracking

    var font: Font {
        switch self {
        case .display: AttaType.serif(34)
        case .displaySm: AttaType.serif(26)
        case .title: AttaType.sans(20, .medium)
        case .body: AttaType.sans(16)
        case .label: AttaType.sans(13, .medium)
        case .caption: AttaType.sans(11)
        case .eyebrow: AttaType.sans(10, .medium)
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .display: 20   // 54 - 34
        case .displaySm: 16 // 42 - 26
        case .title: 12
        case .body: 11
        case .label: 7
        case .caption: 7
        case .eyebrow: 6
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display: -0.2
        case .displaySm, .title, .body: 0
        case .label: 1.1
        case .caption: 0.5
        case .eyebrow: 2
        }
    }
}

extension Text {
    func atta(_ style: AttaTextStyle, _ color: Color) -> some View {
        self.font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
            .lineSpacing(style.lineSpacing / 2)
    }
}
