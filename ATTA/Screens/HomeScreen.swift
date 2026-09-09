import SwiftUI
import StoreKit
import UIKit
import WidgetKit

/// Home is the feed: full-bleed theme, one card per swipe, no tab bar. The
/// top-right dots open a sheet with Widgets, Focus, Saved, Settings.
/// Port of Android HomeScreen.kt.
struct HomeScreen: View {
    @EnvironmentObject var store: AttaStore
    @EnvironmentObject var router: Router
    @Environment(\.atta) var colors
    @Environment(\.requestReview) private var requestReview

    @State private var today = Date()
    @State private var eveningNow = Calendar.current.component(.hour, from: Date()) >= 18
    @State private var showMenu = false
    @State private var showThemes = false

    // AdMob native cards land with the iOS ads pass (Android: NativeAdCard
    // after every 7 lines on the free tier; the page<->feed index mapping
    // returns with it).

    private var feed: [(date: Date, line: Affirmation)] {
        AffirmationRepository.feed(
            today: today,
            days: 30,
            focusIds: Set(store.settings.focusIds),
            evening: eveningNow
        )
    }

    private var theme: WidgetTheme {
        WidgetThemes.byId(store.settings.freeTier ? WidgetThemes.freeThemeId : store.settings.themeId)
    }

    var body: some View {
        let feed = self.feed
        let theme = self.theme
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(feed.indices, id: \.self) { i in
                        let entry = feed[i]
                        let line = entry.line.text(store.settings.language)
                        let isNight = (i == 0 && eveningNow) || entry.line.daypart == .night
                        let eyebrow = (isNight ? "Night" : "Morning")
                            + " · " + AffirmationRepository.shortDate(entry.date, lang: store.settings.language)
                        HomeCard(
                            theme: theme,
                            line: line,
                            eyebrow: eyebrow,
                            saved: store.settings.savedIds.contains(entry.line.id),
                            onToggleSave: { toggleSaved(entry.line.id) },
                            onShare: { ShareCard.share(theme: theme, line: line) },
                            onOpenThemes: { showThemes = true },
                            onOpenMenu: { showMenu = true },
                            showChevron: i < feed.count - 1,
                            onOpenPractice: { router.push(.practice(source: "feed", index: i)) },
                            safeArea: geo.safeAreaInsets
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
        }
        .background(colors.canvas.ignoresSafeArea())
        .ignoresSafeArea()
        .task {
            // Android asks for POST_NOTIFICATIONS on first Home; the iOS
            // system prompt is likewise one-shot.
            _ = await Reminders.requestPermission()
        }
        .task(id: reminderKey) {
            await Reminders.rescheduleAsync(store.settings)
        }
        .sheet(isPresented: $showMenu) {
            NavSheet { route in
                showMenu = false
                router.push(route)
            }
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(colors.canvas)
        }
        .sheet(isPresented: $showThemes) {
            ThemeSheet(
                selectedId: theme.id,
                freeTier: store.settings.freeTier,
                onPick: { picked in
                    showThemes = false
                    store.setThemeId(picked)
                    WidgetCenter.shared.reloadAllTimelines()
                },
                onRequireUpgrade: {
                    showThemes = false
                    router.push(.paywall(source: "upgrade"))
                }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(colors.canvas)
        }
    }

    /// LaunchedEffect(morningHour, morningMinute, eveningLine) parity.
    private var reminderKey: String {
        "\(store.settings.morningHour):\(store.settings.morningMinute):\(store.settings.eveningLine)"
    }

    private func toggleSaved(_ id: String) {
        // Third kept line = the content landed; a good moment to ask for a
        // review (the system rate-limits the prompt, as ReviewPrompter does).
        let isThirdSave = !store.settings.savedIds.contains(id) && store.settings.savedIds.count == 2
        store.toggleSaved(id)
        WidgetCenter.shared.reloadAllTimelines()
        if isThirdSave { requestReview() }
    }
}

/// One full-bleed affirmation card. Shared by the feed and the saved-line viewer.
struct HomeCard: View {
    let theme: WidgetTheme
    let line: String
    let eyebrow: String
    let saved: Bool
    let onToggleSave: () -> Void
    let onShare: () -> Void
    var onOpenThemes: (() -> Void)? = nil
    var onOpenMenu: (() -> Void)? = nil
    let showChevron: Bool
    var onClose: (() -> Void)? = nil
    var onOpenPractice: (() -> Void)? = nil
    var safeArea: EdgeInsets = EdgeInsets()

    var body: some View {
        ZStack {
            DriftingGradient(theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 18)

                // Android weights 1 : 1.2 above/below the line block —
                // SwiftUI splits leftover space evenly across Spacers,
                // so 5 above and 6 below reproduce the exact ratio.
                ForEach(0..<5, id: \.self) { _ in Spacer(minLength: 0) }

                Text(line)
                    .atta(.displaySm, theme.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 320, alignment: .leading)

                Rectangle()
                    .fill(saved ? AttaPalette.champagne : theme.ink.opacity(0.3))
                    .frame(width: 26, height: 1)
                    .padding(.top, 22)

                ForEach(0..<6, id: \.self) { _ in Spacer(minLength: 0) }

                if let onOpenPractice {
                    practicePill(onOpenPractice)
                        .frame(maxWidth: .infinity)
                    Spacer().frame(height: 20)
                }

                bottomRow

                ZStack {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(theme.ink.opacity(0.35))
                        .opacity(showChevron ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, AttaDimens.md)
            .padding(.top, safeArea.top)
            .padding(.bottom, safeArea.bottom)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(theme.ink.opacity(0.55))
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Circle())
                }
                .buttonStyle(TapScaleStyle())
                .accessibilityLabel("Close")
                Spacer(minLength: 0)
            }
            Text(eyebrow.uppercased())
                .font(AttaType.sans(10, .medium))
                .tracking(1.8)
                .foregroundStyle(theme.eyebrowColor)
            Spacer(minLength: 0)
            if let onOpenMenu {
                Button(action: onOpenMenu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(theme.ink.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(TapScaleStyle())
                .accessibilityLabel("Menu")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func practicePill(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "play")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(theme.ink.opacity(0.8))
                Text("Practice")
                    .font(AttaType.sans(11, .medium))
                    .tracking(0.3)
                    .foregroundStyle(theme.ink.opacity(0.8))
            }
            .padding(.horizontal, 22)
            .frame(height: 44)
            .overlay(Capsule().stroke(theme.ink.opacity(0.22), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(TapScaleStyle())
    }

    private var bottomRow: some View {
        HStack {
            HStack(spacing: 12) {
                ActionCircle(
                    theme: theme,
                    description: saved ? "Remove from saved" : "Save this line",
                    action: onToggleSave
                ) {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(saved ? AttaPalette.champagne : theme.ink)
                }
                ActionCircle(theme: theme, description: "Share", action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(theme.ink)
                }
            }
            Spacer(minLength: 0)
            if let onOpenThemes {
                Button(action: onOpenThemes) {
                    HStack(spacing: 7) {
                        ThemeDot(theme: theme, size: 11)
                        Text(theme.displayName)
                            .font(AttaType.sans(11, .medium))
                            .tracking(0.3)
                            .foregroundStyle(theme.ink.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(theme.ink.opacity(0.22), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(TapScaleStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The theme gradient with the slow ambient drift: 10s out, 10s back, linear —
/// the Android drawBehind drift reproduced as a triangle wave over wall time.
private struct DriftingGradient: View {
    let theme: WidgetTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            Canvas { context, size in
                let period = AttaMotion.gradientDrift
                let t = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period * 2) / period
                let drift = t <= 1 ? t : 2 - t

                let (start, end) = theme.gradientPoints(size.width, size.height)
                let dx = end.x - start.x
                let dy = end.y - start.y
                let len = max(hypot(dx, dy), 1)
                let shift = (drift - 0.5) * min(size.width, size.height) * 0.06
                let offset = CGPoint(x: dx / len * shift, y: dy / len * shift)

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(stops: theme.stops.map {
                            .init(color: $0.color, location: $0.location)
                        }),
                        startPoint: CGPoint(x: start.x + offset.x, y: start.y + offset.y),
                        endPoint: CGPoint(x: end.x + offset.x, y: end.y + offset.y)
                    )
                )
            }
        }
    }
}

private struct ActionCircle<Content: View>: View {
    let theme: WidgetTheme
    let description: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(theme.ink.opacity(0.22), lineWidth: 1)
                content
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(TapScaleStyle())
        .accessibilityLabel(description)
    }
}

/// The nav sheet: four quiet serif rows. A five-item chrome under a meditation
/// card would say "app" when the product wants to say "object".
struct NavSheet: View {
    @Environment(\.atta) private var colors
    let onOpen: (Route) -> Void

    private let rows: [(label: String, route: Route)] = [
        ("Widgets", .gallery),
        ("Focus", .focus),
        ("Saved", .saved),
        ("Settings", .settings),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                if i > 0 {
                    Rectangle()
                        .fill(colors.inkAlpha(0.07))
                        .frame(height: 1)
                }
                Button {
                    onOpen(rows[i].route)
                } label: {
                    Text(rows[i].label)
                        .font(AttaType.serif(22))
                        .lineSpacing(6)
                        .foregroundStyle(colors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.xs)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Theme picker. On the free tier only Linen stays unlocked — quietly.
struct ThemeSheet: View {
    @Environment(\.atta) private var colors
    let selectedId: String
    let freeTier: Bool
    let onPick: (String) -> Void
    let onRequireUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Theme")
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
                .padding(.bottom, 10)
            ForEach(WidgetThemes.all) { theme in
                let locked = freeTier && theme.id != WidgetThemes.freeThemeId
                Button {
                    if locked { onRequireUpgrade() } else { onPick(theme.id) }
                } label: {
                    HStack {
                        HStack(spacing: 14) {
                            ThemeDot(theme: theme, size: 22)
                            Text(theme.displayName)
                                .font(AttaType.sans(15))
                                .foregroundStyle(colors.ink)
                        }
                        Spacer(minLength: 0)
                        if theme.id == selectedId {
                            Text("IN USE")
                                .font(AttaType.sans(9, .medium))
                                .tracking(1.2)
                                .foregroundStyle(AttaPalette.champagneDeep)
                        } else if locked {
                            Text("Unlock")
                                .font(AttaType.sans(11))
                                .tracking(0.5)
                                .foregroundStyle(AttaPalette.champagneDeep)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 13)
                    .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusChip))
                }
                .buttonStyle(.plain)
            }
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.xs)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Shares a line as a story-sized card (1080x1920): the theme gradient, the
/// serif line, the champagne rule, a small ATTA mark. Same drawing rules as
/// the widget — authored line breaks, 1.6 line height for Thai tone marks.
/// Port of Android ShareCard.kt via ImageRenderer + UIActivityViewController.
enum ShareCard {
    private static let w: CGFloat = 1080
    private static let h: CGFloat = 1920
    private static let inset: CGFloat = 108

    @MainActor
    static func share(theme: WidgetTheme, line: String) {
        let renderer = ImageRenderer(content: ShareCardView(theme: theme, line: line))
        renderer.scale = 1
        guard let image = renderer.uiImage else { return }
        let caption = "\u{201C}\(line.replacingOccurrences(of: "\n", with: " "))\u{201D} — ATTA"
        let activity = UIActivityViewController(
            activityItems: [image, caption],
            applicationActivities: nil
        )
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        // iPad: the share sheet needs an anchor.
        activity.popoverPresentationController?.sourceView = top.view
        activity.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1
        )
        top.present(activity, animated: true)
    }

    struct ShareCardView: View {
        let theme: WidgetTheme
        let line: String

        var body: some View {
            ZStack {
                theme.gradient(in: CGSize(width: w, height: h))
                // Line block: the line's own center sits at 0.42 * H, the
                // 78x3 rule 70 below its last baseline row (as on Android),
                // so the stack's center is offset by half the rule block.
                VStack(alignment: .leading, spacing: 0) {
                    Text(line)
                        .font(AttaType.serif(76))
                        .lineSpacing(22.8) // 1.6x line height, halved per AttaType convention
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.leading)
                    Rectangle()
                        .fill(theme.ruleColor)
                        .frame(width: 78, height: 3)
                        .padding(.top, 70)
                }
                .frame(width: w - 2 * inset, alignment: .leading)
                .position(x: w / 2, y: h * 0.42 + 36.5)

                VStack {
                    Spacer()
                    Text("ATTA")
                        .font(AttaType.sans(34, .semibold))
                        .tracking(8)
                        .foregroundStyle(theme.eyebrowColor)
                        .padding(.bottom, 130)
                }
            }
            .frame(width: w, height: h)
        }
    }
}
