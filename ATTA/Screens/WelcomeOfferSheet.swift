import SwiftUI

/// The welcome-back offer: a real store discount on the first year, shown to a
/// free user who declined the paywall and came back anyway. One quiet sheet,
/// at most once a day — never a countdown, never a shaking button.
/// Port of Android WelcomeOfferSheet.kt.
struct WelcomeOfferSheet: View {
    @Environment(\.atta) private var colors
    let offer: AttaBilling.WelcomeOffer
    let onTake: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LineArtGem()
                .frame(width: 64, height: 64)
            Spacer().frame(height: 18)
            Text("Welcome back.\nHalf off your first year.")
                .font(AttaType.serif(24))
                .lineSpacing(7) // 38pt line height, halved per AttaType convention
                .foregroundStyle(colors.ink)
                .multilineTextAlignment(.center)
            Spacer().frame(height: AttaDimens.md)
            VStack(alignment: .leading, spacing: 10) {
                OfferRow(text: "Every theme, voice, and scene opens")
                OfferRow(text: "Your line, at your hours, every day")
                if let perMonth = offer.perMonthApprox {
                    OfferRow(text: "\(perMonth) a month, billed once a year")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: AttaDimens.md)
            priceLine
            Spacer().frame(height: AttaDimens.sm)
            PrimaryButton(text: "Take the welcome price", action: onTake)
            Spacer().frame(height: 6)
            Button(action: onDismiss) {
                Text("Not now")
                    .font(AttaType.sans(14))
                    .foregroundStyle(colors.inkAlpha(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusChip))
            }
            .buttonStyle(.plain)
            Spacer().frame(height: 4)
            Text(caption)
                .font(AttaType.sans(10.5))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.45))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.sm)
        .padding(.bottom, AttaDimens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The old price struck through, the welcome price standing.
    private var priceLine: Text {
        var line = Text("")
        if let original = offer.original {
            line = Text(original)
                .font(AttaType.sans(15))
                .strikethrough()
                + Text("  ")
        }
        return (line + Text("\(offer.discounted) / year").font(AttaType.sans(18, .medium)))
            .foregroundStyle(colors.ink)
    }

    private var caption: String {
        "First year only"
            + (offer.original.map { " · then \($0) / year" } ?? "")
            + " · cancel anytime"
    }
}

/// One check row — the same quiet checkmark the Android sheet draws.
private struct OfferRow: View {
    @Environment(\.atta) private var colors
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Canvas { context, size in
                var check = Path()
                check.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.55))
                check.addLine(to: CGPoint(x: size.width * 0.4, y: size.height * 0.85))
                check.addLine(to: CGPoint(x: size.width * 0.9, y: size.height * 0.15))
                context.stroke(
                    check,
                    with: .color(AttaPalette.champagneDeep),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: 13, height: 13)
            Text(text)
                .font(AttaType.sans(14))
                .lineSpacing(4) // 22pt line height, halved
                .foregroundStyle(colors.inkAlpha(0.75))
        }
    }
}

/// Single-stroke gem with two sparks — the brand's line, cut once.
private struct LineArtGem: View {
    @Environment(\.atta) private var colors

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

            // Gem: a slim hexagon with one facet line.
            var gem = Path()
            gem.move(to: CGPoint(x: w * 0.50, y: h * 0.16))
            gem.addLine(to: CGPoint(x: w * 0.70, y: h * 0.34))
            gem.addLine(to: CGPoint(x: w * 0.64, y: h * 0.72))
            gem.addLine(to: CGPoint(x: w * 0.50, y: h * 0.86))
            gem.addLine(to: CGPoint(x: w * 0.36, y: h * 0.72))
            gem.addLine(to: CGPoint(x: w * 0.30, y: h * 0.34))
            gem.closeSubpath()
            gem.move(to: CGPoint(x: w * 0.30, y: h * 0.34))
            gem.addLine(to: CGPoint(x: w * 0.70, y: h * 0.34))
            context.stroke(gem, with: .color(colors.inkAlpha(0.75)), style: stroke)

            // Two champagne sparks.
            let sparks: [(CGPoint, CGFloat)] = [
                (CGPoint(x: w * 0.14, y: h * 0.22), 0.05),
                (CGPoint(x: w * 0.85, y: h * 0.60), 0.04),
            ]
            for (c, r) in sparks {
                var spark = Path()
                spark.move(to: CGPoint(x: c.x - w * r, y: c.y))
                spark.addLine(to: CGPoint(x: c.x + w * r, y: c.y))
                spark.move(to: CGPoint(x: c.x, y: c.y - w * r))
                spark.addLine(to: CGPoint(x: c.x, y: c.y + w * r))
                context.stroke(spark, with: .color(AttaPalette.champagne), style: stroke)
            }
        }
    }
}
