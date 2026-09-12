import SwiftUI

/// The living layer: three soft pools of light drifting over the theme
/// gradient on slow, breath-length loops. The answer to the category's
/// video backgrounds, in the house register — no files, no loops of
/// someone else's footage, just the gradient gently alive. Alphas stay
/// whisper-low so hand-broken lines keep their contrast.
/// Port of Android LivingBackdrop.kt.
struct LivingBackdrop: View {
    let theme: WidgetTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                // Prime-ish periods so the three pools never sync up.
                let t1 = (now / 17).truncatingRemainder(dividingBy: 1)
                let t2 = (now / 23).truncatingRemainder(dividingBy: 1)
                let t3 = (now / 29).truncatingRemainder(dividingBy: 1)

                let w = size.width
                let h = size.height
                let r = min(w, h)

                func pool(
                    _ t: Double,
                    _ cx: CGFloat, _ cy: CGFloat,
                    _ ax: CGFloat, _ ay: CGFloat,
                    _ radius: CGFloat,
                    _ color: Color, _ alpha: Double
                ) {
                    let a = t * 2 * .pi
                    let center = CGPoint(
                        x: w * cx + w * ax * sin(a),
                        y: h * cy + h * ay * cos(a)
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .radialGradient(
                            Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }

                // A warm champagne breath, a cool counterweight, and a soft shadow.
                let glow = theme.lightInk ? Color.white : theme.ink
                pool(t1, 0.30, 0.28, 0.14, 0.10, r * 0.62,
                     Color(atta: 0xC2A57B), theme.lightInk ? 0.10 : 0.07)
                pool(t2, 0.74, 0.62, 0.12, 0.14, r * 0.55,
                     glow, theme.lightInk ? 0.06 : 0.05)
                pool(t3, 0.48, 0.86, 0.16, 0.08, r * 0.5,
                     theme.ink, 0.045)
            }
        }
        .allowsHitTesting(false)
    }
}
