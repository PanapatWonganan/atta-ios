import SwiftUI

/// The last onboarding beat: the widget is the product, so ending on "add it"
/// — with today's real line in the preview — is the whole point of the tour.
///
/// iOS has no requestPinAppWidget equivalent, so instead of the Android pin
/// button this shows the same visual moment plus quiet instructions for adding
/// the widget from the home screen, then a single Continue.
struct WidgetMomentScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors

    var body: some View {
        let settings = store.settings
        let lang = settings.language
        let today = Date()
        let line = AffirmationRepository.lineFor(date: today, focusIds: Set(settings.focusIds))
            .text(lang)
        let date = AffirmationRepository.shortDate(today, lang: lang)
        let theme = WidgetThemes.byId(
            settings.freeTier ? WidgetThemes.freeThemeId : settings.themeId
        )

        VStack(spacing: 0) {
            Spacer(minLength: AttaDimens.lg)
            Eyebrow(
                text: tr(lang, "One last thing", "อีกนิดเดียว"),
                color: colors.inkAlpha(0.4)
            )
            Spacer().frame(height: 14)
            Text(tr(
                lang,
                "Put your line\non the home screen.",
                "วางประโยคของคุณ\nไว้บนหน้าโฮม"
            ))
            .font(AttaType.serif(24))
            .lineSpacing(7)
            .foregroundStyle(colors.ink)
            .multilineTextAlignment(.center)
            Spacer().frame(height: 10)
            Text(tr(
                lang,
                "It changes with the morning.\nNo app to open.",
                "เปลี่ยนใหม่ทุกเช้า\nไม่ต้องเปิดแอป"
            ))
            .font(AttaType.sans(12.5))
            .tracking(0.5)
            .lineSpacing(3.75)
            .foregroundStyle(colors.inkAlpha(0.55))
            .multilineTextAlignment(.center)
            Spacer().frame(height: 28)
            WidgetPreviewCard(theme: theme, line: line, dateLabel: date)
                .aspectRatio(330.0 / 140.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Spacer(minLength: AttaDimens.lg)
            Text(tr(
                lang,
                "Touch and hold the home screen,\nthen add the ATTA widget.",
                "แตะค้างที่หน้าโฮม\nแล้วเพิ่มวิดเจ็ต ATTA"
            ))
            .font(AttaType.sans(12.5))
            .tracking(0.5)
            .lineSpacing(3.75)
            .foregroundStyle(colors.inkAlpha(0.55))
            .multilineTextAlignment(.center)
            Spacer().frame(height: 18)
            PrimaryButton(text: tr(lang, "Continue", "ต่อไป")) {
                store.setOnboardingDone()
                router.popToRoot()
            }
            Spacer().frame(height: AttaDimens.sm)
        }
        .padding(.horizontal, AttaDimens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }
}
