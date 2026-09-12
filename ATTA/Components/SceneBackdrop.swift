import SwiftUI

/// The moving layer behind the line. Plain themes breathe with the light
/// pools; scene themes draw a slow, hand-tuned scene — the sea swelling,
/// rain falling, stars turning — instead of shipping anyone's video files.
/// Everything stays muted enough that the hand-broken lines keep the room.
/// Port of Android SceneBackdrop.kt.
struct ThemeAtmosphere: View {
    let theme: WidgetTheme

    var body: some View {
        Group {
            switch theme.sceneId {
            case "sea": SeaScene(theme: theme)
            case "rain": RainScene(theme: theme)
            case "stars": StarScene(theme: theme)
            default: LivingBackdrop(theme: theme)
            }
        }
        .allowsHitTesting(false)
    }
}

/// One shared wall clock, 0..1 over a minute — scenes derive their own tempo.
private func sceneClock(_ date: Date) -> Double {
    (date.timeIntervalSinceReferenceDate / 60).truncatingRemainder(dividingBy: 1)
}

private func moonGlow(
    _ context: GraphicsContext,
    _ color: Color, _ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat, _ alpha: Double
) {
    let center = CGPoint(x: cx, y: cy)
    context.fill(
        Path(ellipseIn: CGRect(
            x: cx - radius, y: cy - radius,
            width: radius * 2, height: radius * 2
        )),
        with: .radialGradient(
            Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    )
}

/// Deterministic seeds without Foundation's shared generator — the drops
/// and stars must land in the same sky on every launch.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1), 53 bits of mantissa.
    mutating func nextFloat() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

/// Four swells crossing at their own speeds under a low moon.
private struct SeaScene: View {
    let theme: WidgetTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let t = sceneClock(timeline.date)
                let w = size.width
                let h = size.height
                moonGlow(context, .white, w * 0.74, h * 0.18, min(w, h) * 0.4, 0.10)
                // Back swells move slower and sit lighter; the front one is deepest.
                for i in 0..<4 {
                    let fi = CGFloat(i)
                    let baseline = h * (0.58 + fi * 0.115)
                    let amplitude = h * (0.010 + fi * 0.005)
                    let wavelength = w / (1.1 + fi * 0.25)
                    let speed: Double = i % 2 == 0 ? 1 + Double(i) * 0.4 : -(1 + Double(i) * 0.3)
                    let phase = t * speed * 2 * .pi
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: baseline))
                    var x: CGFloat = 0
                    while x <= w {
                        let y = baseline
                            + amplitude * sin(x / wavelength * 2 * .pi + phase)
                            + amplitude * 0.4 * sin(x / (wavelength * 0.53) * 2 * .pi - phase * 1.7)
                        path.addLine(to: CGPoint(x: x, y: y))
                        x += 20
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                    context.fill(path, with: .color(theme.ink.opacity(0.035 + Double(i) * 0.012)))
                }
            }
        }
    }
}

/// Two depths of thin rain, seeded once so the fall never stutters.
private struct RainScene: View {
    let theme: WidgetTheme

    private struct Drop {
        let x: Double
        let speed: Double
        let phase: Double
    }

    private static let drops: [Drop] = {
        var rng = SplitMix64(seed: 42)
        return (0..<44).map { _ in
            Drop(
                x: rng.nextFloat(),
                speed: 0.55 + rng.nextFloat() * 0.9,
                phase: rng.nextFloat()
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let t = sceneClock(timeline.date)
                let w = size.width
                let h = size.height
                moonGlow(context, .white, w * 0.30, h * 0.16, min(w, h) * 0.45, 0.05)
                for (i, drop) in Self.drops.enumerated() {
                    let far = i % 2 == 0 // alternating depth
                    let len = h * (far ? 0.045 : 0.075) * (0.8 + drop.phase * 0.4)
                    // 60s clock -> each drop falls top to bottom in ~1.4-3.4s.
                    let fall = (t * 60 / (1.4 + drop.speed * 2) + drop.phase)
                        .truncatingRemainder(dividingBy: 1)
                    let y = fall * (h + len) - len
                    let drift = w * 0.008 * sin(t * 60 + drop.phase * 7)
                    var line = Path()
                    line.move(to: CGPoint(x: w * drop.x + drift, y: y))
                    line.addLine(to: CGPoint(x: w * drop.x + drift - w * 0.006, y: y + len))
                    context.stroke(
                        line,
                        with: .color(theme.ink.opacity(far ? 0.07 : 0.12)),
                        lineWidth: far ? 1 : 1.6
                    )
                }
            }
        }
    }
}

/// A slow field of stars, each on its own breath, under one still moon.
private struct StarScene: View {
    let theme: WidgetTheme

    private struct Star {
        let x: Double
        let y: Double
        let radius: Double
        let phase: Double
        let period: Double
    }

    private static let stars: [Star] = {
        var rng = SplitMix64(seed: 7)
        return (0..<72).map { _ in
            Star(
                x: rng.nextFloat(),
                y: rng.nextFloat() * 0.78, // keep the lower sky clear for the line
                radius: 0.6 + rng.nextFloat() * 1.1,
                phase: rng.nextFloat(),
                period: 2.5 + rng.nextFloat() * 4
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let t = sceneClock(timeline.date)
                let w = size.width
                let h = size.height
                moonGlow(context, .white, w * 0.26, h * 0.20, min(w, h) * 0.34, 0.10)
                for star in Self.stars {
                    let breathe = 0.5 + 0.5 * sin((t * 60 / star.period + star.phase) * 2 * .pi)
                    let center = CGPoint(x: w * star.x, y: h * star.y)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - star.radius, y: center.y - star.radius,
                            width: star.radius * 2, height: star.radius * 2
                        )),
                        with: .color(theme.ink.opacity(0.12 + 0.30 * breathe))
                    )
                }
            }
        }
    }
}
