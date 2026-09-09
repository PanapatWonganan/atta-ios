import SwiftUI

/// Terms and privacy, readable in-app. The privacy story is short because the
/// data story is short: everything lives on the device. The iOS v1 ships with
/// no analytics and no ads, so the Firebase/AdMob paragraph from Android is
/// replaced with the on-device truth.
struct AboutScreen: View {
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(colors.ink)
                        .frame(width: AttaDimens.touchTarget, height: AttaDimens.touchTarget, alignment: .leading)
                }
                .buttonStyle(TapScaleStyle())
                Spacer()
            }
            .padding(.horizontal, AttaDimens.md)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("About ATTA")
                        .font(AttaType.serif(24))
                        .foregroundStyle(colors.ink)
                    Spacer().frame(height: 6)
                    Text("Version 1.0")
                        .font(AttaType.sans(11))
                        .tracking(0.5)
                        .foregroundStyle(colors.inkAlpha(0.45))

                    section("PRIVACY")
                    bodyText(
                        "ATTA keeps your words on your device. Your saved lines, your own " +
                        "lines, check-in history, and settings are stored locally and " +
                        "included in your phone's standard iOS backup — we never " +
                        "see them.\n\n" +
                        "This iOS version keeps your data on your device. There are no " +
                        "analytics, no crash reports, and no ads in this version. " +
                        "We do not sell personal data.\n\n" +
                        "The voice that reads your lines is your device's own " +
                        "text-to-speech engine, running on the device. If you share a " +
                        "line as an image, it is shared only through the app you " +
                        "choose in the share sheet."
                    )

                    section("TERMS")
                    bodyText(
                        "ATTA offers a free tier and an optional paid tier (ATTA full) " +
                        "that unlocks all widget themes, practice sounds, and your own " +
                        "lines. Subscriptions are billed through the App Store and can " +
                        "be cancelled there at any time; the paid features remain " +
                        "yours until the end of the paid period.\n\n" +
                        "ATTA's lines are reflections, not medical or psychological " +
                        "advice. If you are struggling, please reach out to someone " +
                        "you trust or a professional — the app is a companion, not a " +
                        "substitute.\n\n" +
                        "The app is provided as-is; we work to keep it quiet, honest, " +
                        "and dependable."
                    )

                    section("CONTACT")
                    bodyText("theapppresso@gmail.com")
                    Spacer().frame(height: AttaDimens.xl)
                }
                .padding(.horizontal, AttaDimens.md)
                .padding(.top, 8)
                .padding(.bottom, AttaDimens.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }

    private func section(_ text: String) -> some View {
        Eyebrow(text: text, color: colors.inkAlpha(0.4))
            .padding(.top, 26)
            .padding(.bottom, 8)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(AttaType.sans(13.5))
            .lineSpacing(4.75)
            .foregroundStyle(colors.inkAlpha(0.75))
    }
}
