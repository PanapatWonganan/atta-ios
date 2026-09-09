import WidgetKit
import SwiftUI

/// The home-screen widget: one quiet line on the user's chosen gradient.
/// Same deterministic repository as the app, so feed, notification, and
/// widget always show the same line for a given day.
@main
struct AttaWidgetBundle: WidgetBundle {
    var body: some Widget {
        AttaWidget()
    }
}

struct AttaEntry: TimelineEntry {
    let date: Date
    let line: Affirmation
    let theme: WidgetTheme
    let language: String
}

struct AttaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AttaEntry {
        entry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AttaEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttaEntry>) -> Void) {
        // One entry per day for a week; the deterministic repository makes
        // every future entry computable now.
        let calendar = Calendar.current
        let entries: [AttaEntry] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            let at = offset == 0 ? Date() : calendar.startOfDay(for: day)
            return entry(for: at)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> AttaEntry {
        let settings = AttaStore.snapshot()
        // Free tier keeps Linen; the other themes are the upgrade.
        let themeId = settings.freeTier ? WidgetThemes.freeThemeId : settings.themeId
        return AttaEntry(
            date: date,
            line: AffirmationRepository.lineFor(date: date, focusIds: Set(settings.focusIds)),
            theme: WidgetThemes.byId(themeId),
            language: settings.language
        )
    }
}

/// Layout, all themes (Phase A §03): eyebrow at top-left inset 28pt, rule at
/// top-right; affirmation block bottom-aligned; date at the bottom. Mirrors
/// the Android WidgetRenderer geometry.
struct AttaWidgetView: View {
    let entry: AttaEntry
    @Environment(\.widgetFamily) private var family

    private var inset: CGFloat { family == .systemSmall ? 18 : 28 }
    private var lineSize: CGFloat { family == .systemSmall ? 15 : 19 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.theme.displayName.uppercased())
                    .font(AttaType.sans(9.5, .semibold))
                    .tracking(2.2)
                    .foregroundStyle(entry.theme.eyebrowColor)
                Spacer()
                Rectangle()
                    .fill(entry.theme.ruleColor)
                    .frame(width: 26, height: 1)
            }
            Spacer(minLength: 0)
            Text(entry.line.text(entry.language))
                .font(AttaType.serif(lineSize))
                .lineSpacing(lineSize * 0.6)
                .foregroundStyle(entry.theme.ink)
                .padding(.bottom, 10)
            Text(AffirmationRepository.shortDate(entry.date, lang: entry.language))
                .font(AttaType.sans(9.5))
                .tracking(0.5)
                .foregroundStyle(entry.theme.dateColor)
        }
        .padding(inset)
        .widgetURL(URL(string: "atta://line/\(entry.line.id)"))
        .containerBackground(for: .widget) {
            GeometryReader { geo in
                entry.theme.gradient(in: geo.size)
            }
            .overlay {
                if entry.theme.hairline {
                    ContainerRelativeShape()
                        .stroke(Color(atta: 0xF2EDE6).opacity(0.07), lineWidth: 1)
                }
            }
        }
    }
}

struct AttaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AttaWidget", provider: AttaProvider()) { entry in
            AttaWidgetView(entry: entry)
        }
        .configurationDisplayName("ATTA")
        .description("One quiet line, every morning.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
