import SwiftUI

/// A saved line reopened full-screen in its theme.
/// Port of Android ViewerScreen (HomeScreen.kt) — the same HomeCard with the
/// chrome trimmed: close chevron instead of the menu, category as the eyebrow,
/// no theme pill, no practice pill, no page chevron.
struct ViewerScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @Environment(\.atta) var colors

    let line: Affirmation

    var body: some View {
        let settings = store.settings
        let theme = WidgetThemes.byId(settings.freeTier ? WidgetThemes.freeThemeId : settings.themeId)
        let text = line.text(settings.language)
        GeometryReader { geo in
            HomeCard(
                theme: theme,
                line: text,
                eyebrow: Categories.name(line.categoryId, settings.language),
                saved: settings.savedIds.contains(line.id),
                onToggleSave: { store.toggleSaved(line.id) },
                onShare: { ShareCard.share(theme: theme, line: text) },
                showChevron: false,
                onClose: { router.pop() },
                safeArea: geo.safeAreaInsets
            )
        }
        .background(colors.canvas.ignoresSafeArea())
        .ignoresSafeArea()
    }
}
