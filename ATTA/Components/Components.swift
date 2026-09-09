import SwiftUI

/// The one primary action per screen: ink slab, 14pt radius, 120ms 0.98 tap feedback.
struct PrimaryButton: View {
    @Environment(\.atta) private var colors
    let text: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AttaType.sans(15, .medium))
                .tracking(0.4)
                .foregroundStyle(colors.onInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(colors.ink)
                .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
        }
        .buttonStyle(TapScaleStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

/// 120ms scale-to-0.98 press feedback — the app's only touch response.
struct TapScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AttaMotion.tapScale : 1)
            .animation(AttaMotion.ease(AttaMotion.tap), value: configuration.isPressed)
    }
}

/// Single-select answer / category card. Selection is a hairline, not a fill.
struct OptionCard: View {
    @Environment(\.atta) private var colors
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(AttaType.sans(15))
                    .foregroundStyle(selected ? colors.ink : colors.inkAlpha(0.8))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if selected {
                    ZStack {
                        Circle().fill(AttaPalette.champagne).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(colors.canvas)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            .background(selected ? colors.card : colors.canvasAlt)
            .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: AttaDimens.radiusButton)
                        .stroke(AttaPalette.champagne, lineWidth: 1)
                }
            }
        }
        .buttonStyle(TapScaleStyle())
    }
}

/// The breathing ring — 4s in, 6s out on a 10s loop. Onboarding's processing
/// state and the app's only loading indicator: never a spinner, never a shimmer.
struct BreathingRing: View {
    var size: CGFloat = 120
    @State private var inhale = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(AttaPalette.champagne.opacity(inhale ? 0.85 : 0.55), lineWidth: 1)
                .scaleEffect(inhale ? 1.12 : 1)
            Circle()
                .stroke(AttaPalette.champagne.opacity(0.4), lineWidth: 1)
                .scaleEffect(1 - 18 / 60)
            Circle()
                .fill(AttaPalette.champagne)
                .frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
        .onAppear {
            // Asymmetric breath: 4s in, then 6s out, looping.
            withAnimation(
                .timingCurve(0.42, 0, 0.58, 1, duration: AttaMotion.breathIn)
                .repeatForever(autoreverses: true)
            ) {
                inhale = true
            }
        }
    }
}

/// Champagne pill toggle — the app's only toggle style.
struct AttaToggle: View {
    @Environment(\.atta) private var colors
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(AttaMotion.ease(AttaMotion.tap * 2)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(isOn ? AttaPalette.champagne : colors.inkAlpha(0.18))
                Circle()
                    .fill(colors.canvas)
                    .frame(width: 20, height: 20)
                    .padding(3)
            }
            .frame(width: 44, height: 26)
        }
        .buttonStyle(.plain)
    }
}

/// Rounded gradient surface carrying a theme, used by cards and previews.
struct ThemeSurface<Content: View>: View {
    let theme: WidgetTheme
    let radius: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background {
                GeometryReader { geo in
                    theme.gradient(in: geo.size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                if theme.hairline {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color(atta: 0xF2EDE6).opacity(0.07), lineWidth: 1)
                }
            }
    }
}

/// Gradient swatch dot for theme pickers and chips.
struct ThemeDot: View {
    @Environment(\.atta) private var colors
    let theme: WidgetTheme
    let size: CGFloat

    var body: some View {
        GeometryReader { geo in
            theme.gradient(in: geo.size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(colors.inkAlpha(0.2), lineWidth: 1))
    }
}

/// Widget preview: eyebrow at top, hand-broken affirmation bottom-left, date stamp.
/// Mirrors the layout the real widget renders.
struct WidgetPreviewCard: View {
    let theme: WidgetTheme
    let line: String
    let dateLabel: String

    var body: some View {
        ThemeSurface(theme: theme, radius: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(theme.displayName.uppercased())
                        .font(AttaType.sans(9, .medium))
                        .tracking(1.8)
                        .foregroundStyle(theme.eyebrowColor)
                    Spacer()
                    Rectangle()
                        .fill(theme.ruleColor)
                        .frame(width: 22, height: 1)
                }
                Spacer(minLength: 0)
                Text(line)
                    .font(AttaType.serif(15))
                    .lineSpacing(5)
                    .foregroundStyle(theme.ink)
                    .padding(.vertical, 10)
                Text(dateLabel)
                    .font(AttaType.sans(9))
                    .tracking(0.5)
                    .foregroundStyle(theme.dateColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
}

/// Section eyebrow used across screens.
struct Eyebrow: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(AttaType.sans(10, .medium))
            .tracking(2)
            .foregroundStyle(color)
    }
}
