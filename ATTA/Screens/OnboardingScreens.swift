import SwiftUI

// MARK: - Welcome

/// Welcome: no carousel, no skip button to manage. One promise, one action.
struct WelcomeScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @Environment(\.atta) var colors

    var body: some View {
        VStack(spacing: 0) {
            // Compose weights 1f above / 1.3f below — three equal shares over
            // four lands within a point of the same split.
            ForEach(0..<3, id: \.self) { _ in Spacer(minLength: 0) }

            Rectangle()
                .fill(AttaPalette.champagne)
                .frame(width: 1, height: 44)
            Spacer().frame(height: 22)
            Text("ATTA")
                .font(AttaType.serif(28))
                .tracking(8)
                .foregroundStyle(colors.ink)
                .padding(.leading, 8) // recenter the trailing tracking
            Spacer().frame(height: 22)
            Text("One quiet line, every morning, on your home screen.")
                .font(AttaType.serif(20, .medium))
                .lineSpacing(6)
                .foregroundStyle(colors.inkAlpha(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            ForEach(0..<4, id: \.self) { _ in Spacer(minLength: 0) }

            PrimaryButton(text: "Begin") { router.push(.questions) }
            Spacer().frame(height: 14)
            Text("Takes about a minute")
                .atta(.caption, colors.inkAlpha(0.5))
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }
}

// MARK: - Questions

private struct Question {
    let prompt: String
    let options: [String]
}

private let onboardingQuestions: [Question] = [
    Question(
        prompt: "What brings you here?",
        options: [
            "Manifesting the life I want",
            "A calmer start to the day",
            "Kinder self-talk",
            "Better nights",
        ]
    ),
    Question(
        prompt: "What do your mornings usually feel like?",
        options: ["Rushed before I'm awake", "Fine, but a little flat", "Heavy to get moving", "Quiet — I want to keep it"]
    ),
    Question(
        prompt: "Which voice lands best?",
        options: ["Gentle reminders", "Straight talk, kindly", "Short and spare", "Warm encouragement"]
    ),
    Question(
        prompt: "Where does your energy dip?",
        options: ["Early morning", "Midday", "Evenings", "Late night"]
    ),
    Question(
        prompt: "What should this week make room for?",
        options: ["Rest", "Focus", "Courage", "Gratitude"]
    ),
    Question(
        prompt: "How many lines a day?",
        options: ["Once, in the morning", "Three, spread out", "Five, spread out", "Ten — keep them coming"]
    ),
]

private func clamp03(_ value: Int) -> Int { min(max(value, 0), 3) }

private func deriveFocus(_ answers: [Int]) -> [String] {
    let q1 = ["manifest", "calm-mornings", "self-worth", "nights"]
    let q2 = ["calm-mornings", "gratitude", "rest", "calm-mornings"]
    let q5 = ["rest", "focus-work", "courage", "gratitude"]
    // Manifest is the product's center of gravity: it leads every first week.
    var picks: [String] = []
    for id in ["manifest", q1[clamp03(answers[0])], q5[clamp03(answers[4])], q2[clamp03(answers[1])]]
    where !picks.contains(id) {
        picks.append(id)
    }
    for id in ["self-worth", "healing", "love"]
    where picks.count < Categories.maxSelected && !picks.contains(id) {
        picks.append(id)
    }
    return Array(picks.prefix(Categories.maxSelected))
}

private func deriveTheme(_ answers: [Int]) -> String {
    ["dawn", "sage", "dusk", "onyx"][clamp03(answers[3])]
}

private func derivePerDay(_ answers: [Int]) -> Int {
    [1, 3, 5, 10][clamp03(answers[5])]
}

/// Six single-select cards, hairline progress. Answers seed focus + first theme.
struct QuestionsScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @Environment(\.atta) var colors
    @State private var index = 0
    @State private var answers = Array(repeating: -1, count: onboardingQuestions.count)

    var body: some View {
        let question = onboardingQuestions[index]
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(onboardingQuestions.indices, id: \.self) { i in
                    Rectangle()
                        .fill(i <= index ? AttaPalette.champagne : colors.inkAlpha(0.12))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, AttaDimens.xs)
            Spacer().frame(height: AttaDimens.lg)
            Eyebrow(text: "\(index + 1) of \(onboardingQuestions.count)", color: colors.inkAlpha(0.45))
            Spacer().frame(height: 12)
            Text(question.prompt)
                .font(AttaType.serif(24))
                .lineSpacing(7)
                .foregroundStyle(colors.ink)
                .frame(maxWidth: 300, alignment: .leading)
            Spacer().frame(height: AttaDimens.md)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(question.options.indices, id: \.self) { i in
                        OptionCard(
                            text: question.options[i],
                            selected: answers[index] == i
                        ) {
                            answers[index] = i
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer().frame(height: AttaDimens.sm)
            PrimaryButton(
                text: "Continue",
                enabled: answers[index] >= 0
            ) {
                if index < onboardingQuestions.count - 1 {
                    index += 1
                } else {
                    store.setFocusIds(deriveFocus(answers))
                    store.setThemeId(deriveTheme(answers))
                    store.setRemindersPerDay(derivePerDay(answers))
                    router.push(.processing)
                }
            }
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }
}

// MARK: - Processing

/// The breathing ring doubles as the app's loading state everywhere.
struct ProcessingScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @Environment(\.atta) var colors

    var body: some View {
        VStack(spacing: 0) {
            BreathingRing(size: 120)
            Spacer().frame(height: 36)
            Text("Shaping your first week")
                .font(AttaType.serif(20, .medium))
                .lineSpacing(6)
                .foregroundStyle(colors.inkAlpha(0.85))
                .multilineTextAlignment(.center)
            Spacer().frame(height: 10)
            Text("Choosing lines that match\nyour mornings")
                .font(AttaType.sans(13))
                .tracking(0.5)
                .lineSpacing(4.5)
                .foregroundStyle(colors.inkAlpha(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(AttaDimens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
        .task {
            try? await Task.sleep(nanoseconds: 3_600_000_000)
            router.push(.result)
        }
    }
}

// MARK: - Result

/// The one sage screen. The CTA promises the product, not the paywall.
struct ResultScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @Environment(\.atta) var colors

    private var names: [String] {
        store.settings.focusIds.compactMap { Categories.byId($0)?.name(store.settings.language) }
    }

    private var headline: String {
        let joined = names
            .map { $0.prefix(1).lowercased() + $0.dropFirst() }
            .joined(separator: ", ")
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: AttaDimens.xl)
            Eyebrow(text: "Your practice", color: AttaPalette.sageDeep)
            Spacer().frame(height: 14)
            Text(headline)
                .font(AttaType.serif(24))
                .lineSpacing(7)
                .foregroundStyle(colors.ink)
                .frame(maxWidth: 300, alignment: .leading)
            Spacer().frame(height: 14)
            Text("Your first week draws from these three. You can change them anytime.")
                .font(AttaType.sans(14))
                .lineSpacing(5)
                .foregroundStyle(colors.inkAlpha(0.6))
                .frame(maxWidth: 300, alignment: .leading)
            Spacer().frame(height: AttaDimens.md)
            VStack(spacing: 10) {
                ForEach(names, id: \.self) { name in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AttaPalette.sage)
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(AttaType.sans(14, .medium))
                            .lineSpacing(3)
                            .foregroundStyle(colors.ink)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(colors.canvasAlt)
                    .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(text: "See my first line") {
                router.push(.paywall(source: "onboarding"))
            }
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }
}
