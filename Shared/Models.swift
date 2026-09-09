import SwiftUI

enum Daypart {
    case morning, night, any
}

/// Affirmations are hand-broken, not auto-wrapped: each line is authored as a
/// phrase and stored with its breaks. Never re-wrap these — the default
/// character wrap splits Thai vowel clusters.
struct Affirmation: Identifiable, Hashable {
    let id: String
    let en: String
    let th: String
    let categoryId: String
    var daypart: Daypart = .any

    func text(_ lang: String) -> String { lang == "th" ? th : en }
}

/// Two-language copy helper: the app ships real Thai, not machine translation.
func tr(_ lang: String, _ en: String, _ th: String) -> String {
    lang == "th" ? th : en
}

enum Plans {
    static let none = "none"
    static let free = "free"
    static let trialWeekly = "trial_weekly"
    static let trialYearly = "trial_yearly"
    static let lifetime = "lifetime"

    static func isFree(_ plan: String) -> Bool { plan == free || plan == none }

    static func label(_ plan: String) -> String {
        switch plan {
        case trialWeekly: "Weekly · trial"
        case trialYearly: "Yearly · trial"
        case lifetime: "Lifetime"
        case free: "Free"
        default: "—"
        }
    }
}

/// Thirteen focus categories. Each maps to one muted accent per the brief:
/// sage = calm, clay = self & love & drive, deep teal = strength & work,
/// plum = night & intention.
struct Category: Identifiable, Hashable {
    let id: String
    let en: String
    let th: String
    let accent: Color

    func name(_ lang: String) -> String { lang == "th" ? th : en }
}

enum Categories {
    static let all: [Category] = [
        Category(id: "manifest", en: "Manifest", th: "ดึงดูดสิ่งดี", accent: AttaPalette.plum),
        Category(id: "calm-mornings", en: "Calm mornings", th: "เช้าที่สงบ", accent: AttaPalette.sage),
        Category(id: "self-worth", en: "Self-worth", th: "คุณค่าในตัวเอง", accent: AttaPalette.clay),
        Category(id: "boundaries", en: "Boundaries", th: "ขอบเขตของใจ", accent: AttaPalette.deepTeal),
        Category(id: "love", en: "Love", th: "ความรัก", accent: AttaPalette.clay),
        Category(id: "focus-work", en: "Focus at work", th: "สมาธิกับงาน", accent: AttaPalette.deepTeal),
        Category(id: "gratitude", en: "Gratitude", th: "ขอบคุณสิ่งที่มี", accent: AttaPalette.sage),
        Category(id: "rest", en: "Rest", th: "การพักผ่อน", accent: AttaPalette.sage),
        Category(id: "healing", en: "Healing", th: "การเยียวยา", accent: AttaPalette.clay),
        Category(id: "courage", en: "Courage", th: "ความกล้า", accent: AttaPalette.deepTeal),
        Category(id: "nights", en: "Nights", th: "ค่ำคืน", accent: AttaPalette.plum),
        Category(id: "business", en: "Business inspiration", th: "เส้นทางธุรกิจ", accent: AttaPalette.deepTeal),
        Category(id: "motivation", en: "Motivation", th: "พลังใจ", accent: AttaPalette.clay),
    ]

    static let maxSelected = 3

    static func byId(_ id: String?) -> Category? { all.first { $0.id == id } }

    static func name(_ id: String?, _ lang: String) -> String { byId(id)?.name(lang) ?? "" }
}

/// The user's own lines, stored in settings as "<id>\u{1}<text>" entries. They
/// surface as ordinary Affirmations (same text in both languages) so the saved
/// list and the practice queue treat them like the built-in ones.
enum CustomLines {
    static let categoryId = "custom"
    private static let sep: Character = "\u{1}"

    static func encode(id: String, text: String) -> String { "\(id)\(sep)\(text)" }

    static func parse(_ raw: [String]) -> [Affirmation] {
        raw.compactMap { entry -> Affirmation? in
            guard let split = entry.firstIndex(of: sep), split != entry.startIndex else { return nil }
            let text = String(entry[entry.index(after: split)...])
            return Affirmation(
                id: String(entry[..<split]),
                en: text,
                th: text,
                categoryId: categoryId
            )
        }
        .sorted { $0.id > $1.id }
    }

    static func newId() -> String {
        "custom-\(Int(Date().timeIntervalSince1970 * 1000))"
    }
}
