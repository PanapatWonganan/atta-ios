import SwiftUI

// MARK: - Shared header

/// Pushed screens on Android lean on the system back gesture; on iOS the nav
/// bar is hidden, so each secondary screen carries this quiet chevron instead.
private struct ScreenBack: View {
    @Environment(\.atta) private var colors
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(colors.ink)
                    .frame(width: AttaDimens.touchTarget, height: AttaDimens.touchTarget, alignment: .leading)
            }
            .buttonStyle(TapScaleStyle())
            Spacer()
        }
    }
}

// MARK: - Saved

/// Plain reading list; tap a line to reopen it full-screen in its theme.
struct SavedScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors
    @State private var showEditor = false

    var body: some View {
        let settings = store.settings
        let saved = Affirmations.all.filter { settings.savedIds.contains($0.id) }
        let custom = CustomLines.parse(settings.customLines)
        let freeTier = settings.freeTier

        VStack(alignment: .leading, spacing: 0) {
            ScreenBack { router.pop() }

            HStack(alignment: .bottom) {
                Text("Saved")
                    .font(AttaType.serif(24))
                    .foregroundStyle(colors.ink)
                Spacer()
                if !saved.isEmpty || !custom.isEmpty {
                    // Listen to the whole list, your own lines first.
                    Button {
                        router.push(.practice(source: "saved", index: 0))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(AttaPalette.champagneDeep)
                            Text("Listen")
                                .font(AttaType.sans(12, .medium))
                                .tracking(0.3)
                                .foregroundStyle(AttaPalette.champagneDeep)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(TapScaleStyle())
                }
            }
            .padding(.top, 8)

            Button {
                if freeTier {
                    router.push(.paywall(source: "upgrade"))
                } else {
                    showEditor = true
                }
            } label: {
                Text("+ Your own line")
                    .font(AttaType.sans(13, .medium))
                    .tracking(0.3)
                    .foregroundStyle(AttaPalette.champagneDeep)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
            }
            .buttonStyle(TapScaleStyle())
            .padding(.top, 10)

            if !custom.isEmpty {
                VStack(spacing: 10) {
                    ForEach(custom) { line in
                        HStack {
                            Text(line.text(settings.language).replacingOccurrences(of: "\n", with: " "))
                                .font(AttaType.serif(16))
                                .lineSpacing(5)
                                .foregroundStyle(colors.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                store.removeCustomLine(id: line.id)
                            } label: {
                                Text("\u{2715}")
                                    .font(AttaType.sans(11))
                                    .tracking(0.5)
                                    .foregroundStyle(colors.inkAlpha(0.35))
                                    .padding(10)
                            }
                            .buttonStyle(TapScaleStyle())
                            .accessibilityLabel("Remove this line")
                        }
                        .padding(.leading, 18)
                        .padding(.trailing, 10)
                        .padding(.vertical, 16)
                        .background(colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
                    }
                }
                Spacer().frame(height: 6)
            }

            if saved.isEmpty && custom.isEmpty {
                // No illustration, no mascot: the outline bookmark and two quiet lines.
                VStack(spacing: 0) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(colors.inkAlpha(0.3))
                    Spacer().frame(height: 16)
                    Text("Nothing kept yet.")
                        .font(AttaType.serif(16))
                        .foregroundStyle(colors.inkAlpha(0.7))
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 10)
                    Text("When a line lands, save it here.\nThe good ones are worth rereading.")
                        .font(AttaType.sans(12))
                        .tracking(0.5)
                        .lineSpacing(4)
                        .foregroundStyle(colors.inkAlpha(0.45))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, AttaDimens.xxl)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(saved) { affirmation in
                            SavedLineCard(affirmation: affirmation)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, AttaDimens.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, AttaDimens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.canvas.ignoresSafeArea())
        .sheet(isPresented: $showEditor) {
            CustomLineEditor { text in
                showEditor = false
                store.addCustomLine(CustomLines.encode(id: CustomLines.newId(), text: text))
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationBackground(colors.canvas)
        }
    }
}

private struct SavedLineCard: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors
    let affirmation: Affirmation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(affirmation.text(store.settings.language).replacingOccurrences(of: "\n", with: " "))
                .font(AttaType.serif(16))
                .lineSpacing(5)
                .foregroundStyle(colors.ink)
                .multilineTextAlignment(.leading)
            HStack {
                Eyebrow(
                    text: Categories.name(affirmation.categoryId, store.settings.language),
                    color: colors.inkAlpha(0.4)
                )
                Spacer()
                Button {
                    store.toggleSaved(affirmation.id)
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(AttaPalette.champagne)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(TapScaleStyle())
                .accessibilityLabel("Remove from saved")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.card)
        .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
        .contentShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
        .onTapGesture {
            router.push(.line(id: affirmation.id))
        }
    }
}

/// One field, one button. Their words become part of the practice queue.
private struct CustomLineEditor: View {
    @Environment(\.atta) private var colors
    let onSave: (String) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your own line")
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
            Spacer().frame(height: 6)
            Text("In your words. Read back to you each practice.")
                .font(AttaType.sans(12))
                .tracking(0.5)
                .foregroundStyle(colors.inkAlpha(0.5))
            Spacer().frame(height: 16)
            TextEditor(text: $text)
                .font(AttaType.serif(19))
                .foregroundStyle(colors.ink)
                .tint(AttaPalette.champagne)
                .scrollContentBackground(.hidden)
                .padding(13)
                .frame(minHeight: 96, maxHeight: 120)
                .background(colors.card)
                .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
                .onChange(of: text) { _, newValue in
                    if newValue.count > 140 { text = String(newValue.prefix(140)) }
                }
            Spacer().frame(height: 18)
            PrimaryButton(
                text: "Keep",
                enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Settings

private enum SettingsSheet: String, Identifiable {
    case theme, appearance, language, times, from, until
    var id: String { rawValue }
}

/// Hairline rows, no icons, no cards. The one toggle is champagne.
struct SettingsScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors
    @State private var sheet: SettingsSheet?

    var body: some View {
        let settings = store.settings
        let theme = WidgetThemes.byId(settings.themeId)

        VStack(spacing: 0) {
            ScreenBack { router.pop() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(AttaType.serif(24))
                        .foregroundStyle(colors.ink)
                        .padding(.top, 8)
                    Spacer().frame(height: 14)
                    StreakCard(settings: settings)
                    Spacer().frame(height: 10)

                    SectionLabel(text: "Daily lines")
                    SettingsRow(label: "Times a day", action: { sheet = .times }) {
                        Text("\(settings.remindersPerDay)\u{00D7}")
                            .font(AttaType.sans(14))
                            .foregroundStyle(AttaPalette.champagneDeep)
                    }
                    SettingsRow(label: "From", action: { sheet = .from }) {
                        ValueText(text: String(format: "%d:%02d", settings.morningHour, settings.morningMinute))
                    }
                    SettingsRow(label: "Until", action: { sheet = .until }) {
                        ValueText(text: String(format: "%d:%02d", settings.windowEndHour, settings.windowEndMinute))
                    }
                    SettingsRow(label: "Focus areas", action: { router.push(.focus) }) {
                        ValueText(text: "\(settings.focusIds.count) chosen")
                    }

                    SectionLabel(text: "Appearance")
                    SettingsRow(label: "Theme", action: { sheet = .theme }) {
                        HStack(spacing: 7) {
                            ThemeDot(theme: theme, size: 11)
                            ValueText(text: theme.displayName)
                        }
                    }
                    SettingsRow(label: "App appearance", action: { sheet = .appearance }) {
                        ValueText(text: appearanceLabel(settings.appearance))
                    }
                    SettingsRow(label: "Language", action: { sheet = .language }) {
                        ValueText(text: settings.language == "th" ? "ไทย" : "English")
                    }

                    if !settings.moodLog.isEmpty {
                        SectionLabel(text: "Check-ins")
                        CheckInHistory(moodLog: settings.moodLog)
                    }

                    SectionLabel(text: "Account")
                    SettingsRow(
                        label: "Subscription",
                        divider: false,
                        action: { router.push(.paywall(source: "upgrade")) }
                    ) {
                        ValueText(
                            text: !settings.freeTier && Plans.isFree(settings.plan)
                                ? "Plus \u{00B7} day pass"
                                : Plans.label(settings.plan)
                        )
                    }
                    Spacer().frame(height: AttaDimens.lg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                router.push(.about)
            } label: {
                Text("ATTA 1.0 \u{00B7} Terms \u{00B7} Privacy")
                    .font(AttaType.sans(10))
                    .tracking(0.5)
                    .foregroundStyle(colors.inkAlpha(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .buttonStyle(TapScaleStyle())
        }
        .padding(.horizontal, AttaDimens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
        .sheet(item: $sheet) { which in
            sheetContent(which)
                .presentationDragIndicator(.visible)
                .presentationBackground(colors.canvas)
        }
    }

    private func appearanceLabel(_ value: String) -> String {
        switch value {
        case "light": "Light"
        case "dark": "Dark"
        default: "System"
        }
    }

    /// Reminder-shaped changes ask for permission first, then reschedule.
    private func applyReminderChange(_ change: @escaping () -> Void) {
        Task {
            _ = await Reminders.requestPermission()
            change()
            Reminders.reschedule(store.settings)
        }
    }

    @ViewBuilder
    private func sheetContent(_ which: SettingsSheet) -> some View {
        switch which {
        case .theme:
            SettingsThemeSheet(
                selectedId: store.settings.themeId,
                freeTier: store.settings.freeTier,
                onPick: { picked in
                    sheet = nil
                    store.setThemeId(picked)
                },
                onRequireUpgrade: {
                    sheet = nil
                    router.push(.paywall(source: "upgrade"))
                }
            )
            .presentationDetents([.medium, .large])
        case .appearance:
            OptionSheet(
                title: "App appearance",
                options: [("system", "System"), ("light", "Light"), ("dark", "Dark")],
                selectedKey: store.settings.appearance
            ) { key in
                sheet = nil
                store.setAppearance(key)
            }
            .presentationDetents([.height(236)])
        case .language:
            OptionSheet(
                title: "Language",
                options: [("en", "English"), ("th", "ไทย")],
                selectedKey: store.settings.language
            ) { key in
                sheet = nil
                store.setLanguage(key)
            }
            .presentationDetents([.height(188)])
        case .times:
            OptionSheet(
                title: "Times a day",
                options: [("1", "Once"), ("2", "Twice"), ("3", "3 times"), ("5", "5 times"), ("10", "10 times")],
                selectedKey: String(store.settings.remindersPerDay)
            ) { key in
                sheet = nil
                applyReminderChange { store.setRemindersPerDay(Int(key) ?? 3) }
            }
            .presentationDetents([.height(332)])
        case .from:
            TimeSheet(
                title: "From",
                hour: store.settings.morningHour,
                minute: store.settings.morningMinute
            ) { hour, minute in
                sheet = nil
                applyReminderChange { store.setMorningTime(hour: hour, minute: minute) }
            }
            .presentationDetents([.height(400)])
        case .until:
            TimeSheet(
                title: "Until",
                hour: store.settings.windowEndHour,
                minute: store.settings.windowEndMinute
            ) { hour, minute in
                sheet = nil
                applyReminderChange { store.setWindowEnd(hour: hour, minute: minute) }
            }
            .presentationDetents([.height(400)])
        }
    }
}

/// Eight quiet weeks of one-tap check-ins. Dots, not numbers.
private struct CheckInHistory: View {
    @Environment(\.atta) private var colors
    let moodLog: [String]

    var body: some View {
        let today = Date()
        VStack(alignment: .leading, spacing: 9) {
            ForEach([3, 2, 1, 0], id: \.self) { row in
                HStack(spacing: 9) {
                    ForEach(Array(stride(from: 13, through: 0, by: -1)), id: \.self) { col in
                        let back = row * 14 + col
                        let day = AffirmationRepository.dayKey(
                            Calendar.current.date(byAdding: .day, value: -back, to: today) ?? today
                        )
                        Circle()
                            .fill(dotColor(value(for: day)))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func value(for day: String) -> String? {
        moodLog.first { $0.hasPrefix(day + "|") }.map { String($0.dropFirst(day.count + 1)) }
    }

    private func dotColor(_ value: String?) -> Color {
        switch value {
        case "calm": AttaPalette.champagne
        case "okay": colors.inkAlpha(0.3)
        case "heavy": colors.inkAlpha(0.65)
        default: colors.inkAlpha(0.08)
        }
    }
}

private struct SectionLabel: View {
    @Environment(\.atta) private var colors
    let text: String

    var body: some View {
        Eyebrow(text: text, color: colors.inkAlpha(0.4))
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

private struct ValueText: View {
    @Environment(\.atta) private var colors
    let text: String

    var body: some View {
        Text(text)
            .font(AttaType.sans(14))
            .foregroundStyle(colors.inkAlpha(0.45))
    }
}

private struct SettingsRow<Trailing: View>: View {
    @Environment(\.atta) private var colors
    let label: String
    var divider = true
    let action: () -> Void
    @ViewBuilder let trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(label)
                        .font(AttaType.sans(14.5))
                        .foregroundStyle(colors.ink)
                    Spacer()
                    trailing
                }
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(TapScaleStyle())
            if divider {
                Rectangle()
                    .fill(colors.inkAlpha(0.07))
                    .frame(height: 1)
            }
        }
    }
}

private struct OptionSheet: View {
    @Environment(\.atta) private var colors
    let title: String
    let options: [(String, String)]
    let selectedKey: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
                .padding(.bottom, 10)
            ForEach(options, id: \.0) { key, label in
                Button {
                    onSelect(key)
                } label: {
                    HStack {
                        Text(label)
                            .font(AttaType.sans(15))
                            .foregroundStyle(colors.ink)
                        Spacer()
                        if key == selectedKey {
                            Circle()
                                .fill(AttaPalette.champagne)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TapScaleStyle())
            }
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Theme picker. On the free tier only Linen stays unlocked — quietly.
private struct SettingsThemeSheet: View {
    @Environment(\.atta) private var colors
    let selectedId: String
    let freeTier: Bool
    let onPick: (String) -> Void
    let onRequireUpgrade: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
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
                            Spacer()
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TapScaleStyle())
                }
                Spacer().frame(height: AttaDimens.md)
            }
            .padding(.horizontal, AttaDimens.md)
            .padding(.top, AttaDimens.sm)
        }
    }
}

/// The iOS stand-in for Android's TimePickerDialog: a wheel in the same sheet.
private struct TimeSheet: View {
    @Environment(\.atta) private var colors
    let title: String
    let onSet: (Int, Int) -> Void
    @State private var date: Date

    init(title: String, hour: Int, minute: Int, onSet: @escaping (Int, Int) -> Void) {
        self.title = title
        self.onSet = onSet
        _date = State(initialValue:
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AttaType.serif(20))
                .foregroundStyle(colors.ink)
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .tint(colors.ink)
            PrimaryButton(text: "Set") {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                onSet(comps.hour ?? 0, comps.minute ?? 0)
            }
            Spacer().frame(height: AttaDimens.md)
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.top, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Focus

/// Thirteen categories, choose up to three. Selection is a hairline, not a fill.
struct FocusScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors
    @State private var selected: [String] = []
    @State private var seeded = false

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenBack { router.pop() }
            Spacer().frame(height: AttaDimens.xs)
            Text("Focus")
                .font(AttaType.serif(24))
                .foregroundStyle(colors.ink)
            Spacer().frame(height: 6)
            Text("Choose up to three. Your mornings draw from these.")
                .font(AttaType.sans(12.5))
                .tracking(0.5)
                .lineSpacing(3.75)
                .foregroundStyle(colors.inkAlpha(0.55))
            Spacer().frame(height: 20)
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
                    ForEach(Categories.all) { category in
                        categoryCell(category)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer().frame(height: AttaDimens.sm)
            PrimaryButton(
                text: "Save \u{00B7} \(selected.count) chosen",
                enabled: !selected.isEmpty
            ) {
                store.setFocusIds(selected)
                router.pop()
            }
        }
        .padding(.horizontal, AttaDimens.md)
        .padding(.vertical, AttaDimens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
        .onAppear {
            if !seeded {
                selected = store.settings.focusIds
                seeded = true
            }
        }
    }

    @ViewBuilder
    private func categoryCell(_ category: Category) -> some View {
        let isSelected = selected.contains(category.id)
        Button {
            if let index = selected.firstIndex(of: category.id) {
                selected.remove(at: index)
            } else if selected.count < Categories.maxSelected {
                selected.append(category.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Circle()
                    .fill(isSelected ? AttaPalette.champagne : colors.inkAlpha(0.3))
                    .frame(width: 5, height: 5)
                Text(category.name(store.settings.language))
                    .font(AttaType.sans(12.5, .medium))
                    .foregroundStyle(colors.ink)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? colors.card : colors.canvasAlt)
            .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusButton))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: AttaDimens.radiusButton)
                        .stroke(AttaPalette.champagne, lineWidth: 1)
                }
            }
        }
        .buttonStyle(TapScaleStyle())
    }
}

// MARK: - Widget gallery

/// The selling page: live previews with today's real line, not sample art.
struct WidgetGalleryScreen: View {
    @EnvironmentObject private var store: AttaStore
    @EnvironmentObject private var router: Router
    @Environment(\.atta) private var colors

    var body: some View {
        let settings = store.settings
        let today = Date()
        let line = AffirmationRepository.lineFor(date: today, focusIds: Set(settings.focusIds))
            .text(settings.language)
        let date = AffirmationRepository.shortDate(today, lang: settings.language)
        let freeTier = settings.freeTier
        let activeThemeId = freeTier ? WidgetThemes.freeThemeId : settings.themeId

        VStack(spacing: 0) {
            ScreenBack { router.pop() }
                .padding(.horizontal, AttaDimens.md)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Widgets")
                            .font(AttaType.serif(24))
                            .foregroundStyle(colors.ink)
                        Spacer().frame(height: 6)
                        Text("Pick a theme. It updates with your line each morning.")
                            .font(AttaType.sans(12.5))
                            .tracking(0.5)
                            .lineSpacing(3.75)
                            .foregroundStyle(colors.inkAlpha(0.55))
                    }
                    ForEach(WidgetThemes.all) { theme in
                        themeItem(theme, line: line, date: date, activeThemeId: activeThemeId, freeTier: freeTier)
                    }
                    if freeTier {
                        // the quiet inline upgrade card — never a popup
                        Button {
                            router.push(.paywall(source: "upgrade"))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("The widget is part of ATTA full.")
                                    .font(AttaType.sans(14.5))
                                    .foregroundStyle(colors.inkAlpha(0.8))
                                Text("Start 7 days free")
                                    .font(AttaType.sans(13, .medium))
                                    .tracking(0.3)
                                    .foregroundStyle(AttaPalette.champagneDeep)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colors.canvasAlt)
                            .clipShape(RoundedRectangle(cornerRadius: AttaDimens.radiusCard))
                        }
                        .buttonStyle(TapScaleStyle())
                    }
                }
                .padding(.horizontal, AttaDimens.md)
                .padding(.top, 8)
                .padding(.bottom, AttaDimens.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func themeItem(
        _ theme: WidgetTheme,
        line: String,
        date: String,
        activeThemeId: String,
        freeTier: Bool
    ) -> some View {
        VStack(spacing: 0) {
            WidgetPreviewCard(theme: theme, line: line, dateLabel: date)
                .aspectRatio(330.0 / 140.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            HStack {
                Text(theme.displayName)
                    .font(AttaType.sans(13.5, .medium))
                    .foregroundStyle(colors.ink)
                Spacer()
                if theme.id == activeThemeId {
                    Text("IN USE")
                        .font(AttaType.sans(9.5, .medium))
                        .tracking(1.2)
                        .foregroundStyle(AttaPalette.champagneDeep)
                } else {
                    Button {
                        if freeTier {
                            router.push(.paywall(source: "upgrade"))
                        } else {
                            store.setThemeId(theme.id)
                        }
                    } label: {
                        Text("Use")
                            .font(AttaType.sans(13))
                            .foregroundStyle(colors.inkAlpha(0.45))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(TapScaleStyle())
                }
            }
            .padding(.top, 8)
        }
    }
}
