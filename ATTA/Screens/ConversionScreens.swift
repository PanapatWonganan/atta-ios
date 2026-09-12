import SwiftUI
import AVFoundation
import UserNotifications

/// Pre-paywall persuasion run, ported from the Android pass: the product
/// felt (first line, spoken), a promise made, the difference shown, the ask
/// made plain, the fear removed. House register throughout — no red badges,
/// no star emoji.

/// The aha moment, before any selling: the user's real first line on their
/// derived theme, read aloud once — the product experienced, not described.
struct FirstLineScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @State private var synthesizer = AVSpeechSynthesizer()

    private var theme: WidgetTheme { WidgetThemes.byId(store.settings.themeId) }
    private var line: Affirmation {
        AffirmationRepository.lineFor(date: Date(), focusIds: Set(store.settings.focusIds))
    }

    var body: some View {
        let lang = store.settings.language
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR FIRST LINE")
                .font(AttaType.sans(10, .medium))
                .tracking(2)
                .foregroundStyle(theme.eyebrowColor)
                .padding(.top, AttaDimens.xl)
            Spacer()
            Text(line.text(lang))
                .font(AttaType.serif(30))
                .lineSpacing(10)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: 320, alignment: .leading)
            Rectangle()
                .fill(theme.ruleColor)
                .frame(width: 26, height: 1)
                .padding(.top, 18)
            Spacer()
            Spacer().frame(height: 8)
            Text("Read aloud — the way you'll hear it each morning.")
                .font(AttaType.sans(12))
                .tracking(0.5)
                .foregroundStyle(theme.dateColor)
            Spacer().frame(height: AttaDimens.sm)
            Button {
                synthesizer.stopSpeaking(at: .immediate)
                router.push(.commit)
            } label: {
                Text("Keep it coming")
                    .font(AttaType.sans(15, .medium))
                    .tracking(0.4)
                    .foregroundStyle(theme.lightInk ? Color(atta: 0x1C1917) : Color(atta: 0xF2EDE6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
            }
            .buttonStyle(TapScaleStyle())
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            ZStack {
                GeometryReader { geo in theme.gradient(in: geo.size) }
                // The living layer: pools of light breathing under the first line.
                LivingBackdrop(theme: theme)
            }
            .ignoresSafeArea()
        }
        .task {
            // One spoken line; Practice owns everything longer.
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? await Task.sleep(nanoseconds: 700_000_000)
            let utterance = AVSpeechUtterance(string: line.text(lang).replacingOccurrences(of: "\n", with: " "))
            utterance.voice = AVSpeechSynthesisVoice(language: lang == "th" ? "th-TH" : "en-US")
            utterance.rate = 0.42
            synthesizer.speak(utterance)
        }
        .onDisappear { synthesizer.stopSpeaking(at: .immediate) }
    }
}

/// One promise, one button. Saying it makes keeping it likelier.
struct CommitScreen: View {
    @Environment(\.atta) private var colors
    @EnvironmentObject private var router: Router

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Eyebrow(text: "A small promise", color: AttaPalette.champagneDeep)
            Spacer().frame(height: 14)
            Text("One minute a day.\nThat's all this asks.")
                .font(AttaType.serif(26))
                .lineSpacing(8)
                .foregroundStyle(colors.ink)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 14)
            Text("Meet your line each morning.\nRead it once — out loud, or just to yourself.")
                .font(AttaType.sans(14))
                .lineSpacing(5)
                .foregroundStyle(colors.inkAlpha(0.6))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer().frame(height: 20)
            PrimaryButton(text: "I will") { router.push(.compare) }
            Spacer().frame(height: 14)
            Text("That's the whole commitment")
                .font(AttaType.sans(11))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.5))
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }
}

/// Bars grow on entry; the claim stays modest enough to be true.
struct ComparisonScreen: View {
    @Environment(\.atta) private var colors
    @EnvironmentObject private var router: Router
    @State private var grown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: AttaDimens.xl)
            Eyebrow(text: "Why it works", color: AttaPalette.champagneDeep)
            Spacer().frame(height: 14)
            Text("A habit with a set time\nis twice as likely to stick.")
                .font(AttaType.serif(24))
                .lineSpacing(7)
                .foregroundStyle(colors.ink)
            Spacer().frame(height: AttaDimens.md)
            VStack(spacing: 18) {
                HStack(alignment: .bottom, spacing: 28) {
                    comparisonBar(
                        fraction: grown ? 0.3 : 0.06,
                        fill: colors.inkAlpha(0.16),
                        value: "1×",
                        valueColor: colors.inkAlpha(0.55),
                        label: "On your own"
                    )
                    comparisonBar(
                        fraction: grown ? 0.86 : 0.06,
                        fill: AttaPalette.champagne,
                        value: "2×",
                        valueColor: colors.ink,
                        label: "With ATTA"
                    )
                }
                .frame(height: 210)
                Text("People who tie a new habit to a fixed moment keep it about twice as often. ATTA does the tying — your line, at your hours, already on your home screen.")
                    .font(AttaType.sans(12))
                    .lineSpacing(4)
                    .foregroundStyle(colors.inkAlpha(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background(colors.canvasAlt)
            .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusCard))
            Spacer()
            PrimaryButton(text: "Continue") { router.push(.valueRecap) }
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(colors.canvas.ignoresSafeArea())
        .onAppear {
            withAnimation(AttaMotion.ease(AttaMotion.cardSwipe)) { grown = true }
        }
    }

    private func comparisonBar(
        fraction: CGFloat,
        fill: Color,
        value: String,
        valueColor: Color,
        label: String
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(value)
                .font(AttaType.sans(15, .medium))
                .tracking(0.5)
                .foregroundStyle(valueColor)
            Spacer().frame(height: 8)
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)
                        .fill(fill)
                        .frame(height: max(geo.size.height * fraction, 4))
                }
            }
            .frame(height: 140)
            Spacer().frame(height: 10)
            Text(label)
                .font(AttaType.sans(11))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.55))
        }
    }
}

/// Benefit recap right before the reminder promise: the ask, made plain.
struct ValueRecapScreen: View {
    @Environment(\.atta) private var colors
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router

    var body: some View {
        let lang = store.settings.language
        // Their own picks, folded back into the ask — the quiz was for this.
        let focusLine = store.settings.focusIds
            .compactMap { Categories.byId($0)?.name(lang) }
            .map { $0.prefix(1).lowercased() + $0.dropFirst() }
            .joined(separator: ", ")
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: AttaDimens.xl)
            Text("We'd like you to\ntry ATTA for free.")
                .font(AttaType.serif(26))
                .lineSpacing(8)
                .foregroundStyle(colors.ink)
            if !focusLine.isEmpty {
                Spacer().frame(height: 10)
                Text("Shaped around \(focusLine) — your picks.")
                    .font(AttaType.sans(14))
                    .lineSpacing(5)
                    .foregroundStyle(AttaPalette.champagneDeep)
            }
            Spacer().frame(height: AttaDimens.lg)
            VStack(alignment: .leading, spacing: AttaDimens.md) {
                benefitRow(
                    title: "A line that finds you",
                    body: "On your home screen and at the hours you chose — no opening the app required."
                )
                benefitRow(
                    title: "Spoken, not just read",
                    body: "Each line read aloud over rain or waves, with a timer for falling asleep to."
                )
                benefitRow(
                    title: "Written for your week",
                    body: "Your three focus areas shape every line. Real Thai and real English."
                )
            }
            Spacer()
            HStack(spacing: 10) {
                champagneCheck
                Text("No payment due now")
                    .font(AttaType.sans(14, .medium))
                    .foregroundStyle(colors.ink)
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(height: AttaDimens.sm)
            PrimaryButton(text: "Try for $0.00") { router.push(.trialPromise) }
            Spacer().frame(height: 14)
            Text("7 days free, then $39.99 / year · cancel anytime")
                .font(AttaType.sans(11))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(colors.canvas.ignoresSafeArea())
    }

    private var champagneCheck: some View {
        ZStack {
            Circle().fill(AttaPalette.champagne).frame(width: 18, height: 18)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(colors.canvas)
        }
    }

    private func benefitRow(title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(AttaPalette.champagneDeep)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AttaType.sans(17, .medium))
                    .foregroundStyle(colors.ink)
                Text(body)
                    .font(AttaType.sans(13.5))
                    .lineSpacing(4)
                    .foregroundStyle(colors.inkAlpha(0.55))
            }
        }
    }
}

/// The reminder promise before any price talk removes the sign-up fear —
/// and because this screen has just explained why the reminder matters, it
/// is the one right moment to ask the system for notification permission.
struct TrialPromiseScreen: View {
    @Environment(\.atta) private var colors
    @EnvironmentObject private var router: Router

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LineArtBell()
                .frame(width: 96, height: 96)
            Spacer().frame(height: AttaDimens.lg)
            Text("We'll remind you before\nyour free week ends.")
                .font(AttaType.serif(24))
                .lineSpacing(7)
                .foregroundStyle(colors.ink)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 14)
            Text("A quiet note on day 5. The trial ends on day 7,\nand nothing charges before you say so.")
                .font(AttaType.sans(14))
                .lineSpacing(5)
                .foregroundStyle(colors.inkAlpha(0.6))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer().frame(height: 20)
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(AttaPalette.champagne).frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(colors.canvas)
                }
                Text("No payment due now")
                    .font(AttaType.sans(14, .medium))
                    .foregroundStyle(colors.ink)
            }
            Spacer().frame(height: AttaDimens.sm)
            PrimaryButton(text: "Continue for free") {
                Task {
                    // Granted or not, the flow moves on.
                    _ = await Reminders.requestPermission()
                    router.push(.paywall(source: "onboarding"))
                }
            }
            Spacer().frame(height: 14)
            Text("7 days free, then $39.99 / year · cancel anytime")
                .font(AttaType.sans(11))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.5))
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }
}

/// Single-stroke bell with a champagne dot — the brand's line, bent once.
private struct LineArtBell: View {
    @Environment(\.atta) private var colors

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let ink = colors.inkAlpha(0.75)
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round)

            var bell = SwiftUI.Path()
            bell.move(to: CGPoint(x: w * 0.24, y: h * 0.66))
            bell.addCurve(
                to: CGPoint(x: w * 0.38, y: h * 0.26),
                control1: CGPoint(x: w * 0.30, y: h * 0.60),
                control2: CGPoint(x: w * 0.30, y: h * 0.34)
            )
            bell.addCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.26),
                control1: CGPoint(x: w * 0.44, y: h * 0.20),
                control2: CGPoint(x: w * 0.56, y: h * 0.20)
            )
            bell.addCurve(
                to: CGPoint(x: w * 0.76, y: h * 0.66),
                control1: CGPoint(x: w * 0.70, y: h * 0.34),
                control2: CGPoint(x: w * 0.70, y: h * 0.60)
            )
            context.stroke(bell, with: .color(ink), style: stroke)

            var mouth = SwiftUI.Path()
            mouth.move(to: CGPoint(x: w * 0.20, y: h * 0.66))
            mouth.addLine(to: CGPoint(x: w * 0.80, y: h * 0.66))
            context.stroke(mouth, with: .color(ink), style: stroke)

            var clapper = SwiftUI.Path()
            clapper.addArc(
                center: CGPoint(x: w * 0.5, y: h * 0.70),
                radius: w * 0.06,
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
            context.stroke(clapper, with: .color(ink), style: stroke)

            // The one accent: a champagne dot where a red badge would shout.
            let dot = CGRect(
                x: w * 0.72 - w * 0.045, y: h * 0.22 - w * 0.045,
                width: w * 0.09, height: w * 0.09
            )
            context.fill(SwiftUI.Path(ellipseIn: dot), with: .color(AttaPalette.champagne))
        }
    }
}
