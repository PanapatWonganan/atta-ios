import SwiftUI
import UIKit

/// Wallpapers: every theme carrying today's line, saved to Photos and set
/// from the lock screen — iOS can't set wallpapers directly, so a saved
/// image plus one quiet instruction is the whole flow. Two are free;
/// premium opens them all — the quiet lane to the subscription.
/// Port of Android WallpapersScreen.kt.
struct WallpapersScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors

    @State private var settingTheme: WidgetTheme? // allowed pick — save sheet
    @State private var pendingTheme: WidgetTheme? // gated pick — unlock sheet

    var body: some View {
        let settings = store.settings
        let th = settings.language == "th"
        let today = Date()
        let evening = Calendar.current.component(.hour, from: today) >= 18
        let line = AffirmationRepository.lineFor(
            date: today, focusIds: Set(settings.focusIds), evening: evening
        ).text(settings.language)

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
                .accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, AttaDimens.md)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(th ? "วอลเปเปอร์" : "Wallpapers")
                        .font(AttaType.serif(24))
                        .foregroundStyle(colors.ink)
                    Spacer().frame(height: 6)
                    Text(th
                        ? "ประโยคของวันนี้ บนหน้าจอเครื่องของคุณเลย"
                        : "Today's line, on the phone itself. Set it again any day.")
                        .font(AttaType.sans(12.5))
                        .tracking(0.5)
                        .lineSpacing(3.75)
                        .foregroundStyle(colors.inkAlpha(0.55))
                    Spacer().frame(height: AttaDimens.sm)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible()),
                        ],
                        spacing: 12
                    ) {
                        ForEach(WidgetThemes.all) { theme in
                            WallpaperCard(
                                theme: theme,
                                line: line,
                                freeChip: settings.freeTier && AttaWallpaper.freeIds.contains(theme.id),
                                unlockedChip: settings.freeTier
                                    && settings.unlockedWallpapers.contains(theme.id)
                            ) {
                                if canUse(theme, settings: settings) {
                                    settingTheme = theme
                                } else {
                                    pendingTheme = theme
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AttaDimens.md)
                .padding(.top, 8)
                .padding(.bottom, AttaDimens.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
        .sheet(item: $settingTheme) { theme in
            SaveWallpaperSheet(th: th, theme: theme, line: line) { settingTheme = nil }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(colors.canvas)
        }
        .sheet(item: $pendingTheme) { _ in
            UnlockWallpaperSheet(th: th) {
                pendingTheme = nil
                router.push(.paywall(source: "upgrade"))
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(colors.canvas)
        }
    }

    private func canUse(_ theme: WidgetTheme, settings: AttaSettings) -> Bool {
        !settings.freeTier
            || AttaWallpaper.freeIds.contains(theme.id)
            || settings.unlockedWallpapers.contains(theme.id)
    }
}

/// One 9:16 preview: the theme gradient, today's line small, the rule —
/// a champagne FREE/YOURS chip on the free tier's usable ones.
private struct WallpaperCard: View {
    @Environment(\.atta) private var colors
    let theme: WidgetTheme
    let line: String
    let freeChip: Bool
    let unlockedChip: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ThemeSurface(theme: theme, radius: AttaDimens.radiusCard) {
                ZStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line)
                            .font(AttaType.serif(13))
                            .lineSpacing(4) // 21pt line height, halved per AttaType convention
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer().frame(height: 8)
                        Rectangle()
                            .fill(theme.ruleColor)
                            .frame(width: 18, height: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if freeChip || unlockedChip {
                        Text(freeChip ? "FREE" : "YOURS")
                            .font(AttaType.sans(8, .medium))
                            .tracking(1)
                            .foregroundStyle(colors.canvas)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AttaPalette.champagne)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(10)
                    }
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusCard))
        }
        .buttonStyle(TapScaleStyle())
    }
}

/// Render, save to Photos, say where it went — then leave on its own.
private struct SaveWallpaperSheet: View {
    @Environment(\.atta) private var colors
    let th: Bool
    let theme: WidgetTheme
    let line: String
    let onDone: () -> Void

    @State private var saving = false
    @State private var saved = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            Text(th ? "บันทึกวอลเปเปอร์" : "Save wallpaper")
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
            Spacer().frame(height: 8)
            Text(th
                ? "บันทึกลงรูปภาพแล้ว นำไปตั้งได้จากหน้าล็อกหรือการตั้งค่า"
                : "Saved to your Photos — set it from Settings or your lock screen.")
                .font(AttaType.sans(13.5))
                .lineSpacing(4.25)
                .foregroundStyle(colors.inkAlpha(0.6))
                .multilineTextAlignment(.center)
            Spacer().frame(height: AttaDimens.md)
            if saved {
                // The confirmation holds the button's place, then the sheet goes.
                Text(th ? "บันทึกแล้ว" : "Saved")
                    .font(AttaType.sans(15, .medium))
                    .tracking(0.4)
                    .foregroundStyle(AttaPalette.champagneDeep)
                    .frame(height: 52)
            } else {
                PrimaryButton(text: th ? "บันทึกลงรูปภาพ" : "Save to Photos", enabled: !saving) {
                    save()
                }
            }
            if failed {
                Text(th
                    ? "บันทึกไม่ได้ — เปิดสิทธิ์รูปภาพในการตั้งค่า"
                    : "Couldn't save — allow Photos access in Settings.")
                    .font(AttaType.sans(11))
                    .tracking(0.5)
                    .foregroundStyle(colors.inkAlpha(0.5))
                    .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.md)
    }

    private func save() {
        saving = true
        failed = false
        Task { @MainActor in
            let scale = UIScreen.main.scale
            let size = CGSize(
                width: UIScreen.main.bounds.width * scale,
                height: UIScreen.main.bounds.height * scale
            )
            let image = AttaWallpaper.render(theme: theme, line: line, size: size)
            let ok = await AttaWallpaper.saveToPhotos(image)
            saving = false
            if ok {
                saved = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                onDone()
            } else {
                failed = true
            }
        }
    }
}

/// The gate, kept quiet: one button to premium, one caption underneath.
private struct UnlockWallpaperSheet: View {
    @Environment(\.atta) private var colors
    let th: Bool
    let onPremium: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(th ? "ปลดล็อกวอลเปเปอร์นี้" : "Unlock this wallpaper")
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
            Spacer().frame(height: AttaDimens.md)
            PrimaryButton(text: th ? "สมัครสมาชิก" : "Go Premium", action: onPremium)
            // AdMob rewarded unlock lands with the iOS ads pass (Android:
            // "Unlock by watching an ad" row; unlockedWallpapers persists it).
            Text(th ? "สมาชิกเปิดวอลเปเปอร์ได้ทุกแบบ" : "Premium opens every wallpaper")
                .font(AttaType.sans(11))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.5))
                .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.md)
    }
}
