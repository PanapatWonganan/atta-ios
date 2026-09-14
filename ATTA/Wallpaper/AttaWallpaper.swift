import Photos
import SwiftUI
import UIKit

/// Wallpapers, the ATTA way: no photo packs, no downloads — the theme
/// gradient and the day's line rendered at screen size the moment they're
/// saved. iOS has no WallpaperManager, so the image lands in Photos and the
/// user sets it from the lock screen — the pattern every affirmation app
/// shares. Same drawing rules as the share card and the widget: authored
/// line breaks, 1.6 line height for Thai tone marks.
/// Port of Android wallpaper/AttaWallpaper.kt via ImageRenderer.
enum AttaWallpaper {

    /// Wallpapers the free tier can save outright; the rest are premium.
    static let freeIds: Set<String> = ["linen", "dawn"]

    /// Renders the wallpaper at the given pixel size (pass the device's
    /// native `bounds * scale` so the lock screen never upscales).
    @MainActor
    static func render(theme: WidgetTheme, line: String, size: CGSize) -> UIImage {
        let renderer = ImageRenderer(content: WallpaperView(theme: theme, line: line, size: size))
        renderer.scale = 1
        return renderer.uiImage ?? UIImage()
    }

    /// Add-only Photos access: the narrowest permission that exists — ATTA
    /// can put the wallpaper in, never read the library.
    static func saveToPhotos(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }

    /// Full-bleed gradient, the serif line below center (the lock clock
    /// keeps the upper air), the small rule underneath — proportions match
    /// the Android renderer exactly.
    struct WallpaperView: View {
        let theme: WidgetTheme
        let line: String
        let size: CGSize

        var body: some View {
            let w = size.width
            let h = size.height
            let inset = w * 0.1
            let fontSize = w * 0.062
            let ruleGap = h * 0.036
            let ruleHeight = max(h * 0.0016, 1)
            ZStack {
                theme.gradient(in: size)
                VStack(alignment: .leading, spacing: 0) {
                    Text(line)
                        .font(AttaType.serif(fontSize))
                        .lineSpacing(fontSize * 0.3) // 1.6x line height, halved per AttaType convention
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.leading)
                    Rectangle()
                        .fill(theme.ruleColor)
                        .frame(width: w * 0.072, height: ruleHeight)
                        .padding(.top, ruleGap)
                }
                .frame(width: w - 2 * inset, alignment: .leading)
                // The line's own center sits at 0.52 * H; the stack's center
                // is offset by half the rule block (as the share card does).
                .position(x: w / 2, y: h * 0.52 + (ruleGap + ruleHeight) / 2)
            }
            .frame(width: w, height: h)
        }
    }
}
