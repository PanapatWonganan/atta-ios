import SwiftUI

/// One of the eight widget/card themes from the Phase A sheet. Stops are slow and
/// soft: both end stops sit within 0.35 absolute relative luminance of each other,
/// so the paired ink holds effectively the same contrast at every point.
struct WidgetTheme: Identifiable, Hashable {
    let id: String
    let displayName: String
    let stops: [(location: CGFloat, color: Color)]
    let angleDeg: CGFloat // CSS convention: 0 = up, clockwise
    let ink: Color
    let lightInk: Bool // true when ink is light (dark theme surface)
    let ruleChampagne: Bool // Linen and Onyx carry the champagne rule
    let hairline: Bool // Onyx: 1pt edge at 7% light ink — shadows vanish on black

    static func == (lhs: WidgetTheme, rhs: WidgetTheme) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Gradient endpoints for a w×h surface, matching CSS linear-gradient geometry.
    func gradientPoints(_ w: CGFloat, _ h: CGFloat) -> (CGPoint, CGPoint) {
        let rad = angleDeg * .pi / 180
        let dx = sin(rad)
        let dy = -cos(rad)
        let len = abs(w * sin(rad)) + abs(h * cos(rad))
        let cx = w / 2
        let cy = h / 2
        return (
            CGPoint(x: cx - dx * len / 2, y: cy - dy * len / 2),
            CGPoint(x: cx + dx * len / 2, y: cy + dy * len / 2)
        )
    }

    /// Absolute-geometry gradient for a known size (use inside GeometryReader).
    func gradient(in size: CGSize) -> LinearGradient {
        let (start, end) = gradientPoints(size.width, size.height)
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        return LinearGradient(
            stops: stops.map { .init(color: $0.color, location: $0.location) },
            startPoint: UnitPoint(x: start.x / w, y: start.y / h),
            endPoint: UnitPoint(x: end.x / w, y: end.y / h)
        )
    }

    var eyebrowColor: Color { ink.opacity(lightInk ? 0.55 : 0.5) }
    var dateColor: Color { ink.opacity(lightInk ? 0.48 : 0.44) }
    var ruleColor: Color {
        ruleChampagne ? Color(atta: 0xC2A57B) : ink.opacity(lightInk ? 0.3 : 0.25)
    }
}

enum WidgetThemes {
    static let dawn = WidgetTheme(
        id: "dawn", displayName: "Dawn",
        stops: [(0, Color(atta: 0xF5E7D8)), (0.52, Color(atta: 0xEFD9CB)), (1, Color(atta: 0xE6CBC0))],
        angleDeg: 160, ink: Color(atta: 0x2A211C),
        lightInk: false, ruleChampagne: false, hairline: false
    )

    static let mist = WidgetTheme(
        id: "mist", displayName: "Mist",
        stops: [(0, Color(atta: 0xECEFEE)), (0.5, Color(atta: 0xE0E6E5)), (1, Color(atta: 0xD2DBDA))],
        angleDeg: 150, ink: Color(atta: 0x232A29),
        lightInk: false, ruleChampagne: false, hairline: false
    )

    static let linen = WidgetTheme(
        id: "linen", displayName: "Linen",
        stops: [(0, Color(atta: 0xF7F4EF)), (0.5, Color(atta: 0xEFE8DC)), (1, Color(atta: 0xE4DACB))],
        angleDeg: 165, ink: Color(atta: 0x1C1917),
        lightInk: false, ruleChampagne: true, hairline: false
    )

    static let dusk = WidgetTheme(
        id: "dusk", displayName: "Dusk",
        stops: [(0, Color(atta: 0x6B5C70)), (0.55, Color(atta: 0x584B5E)), (1, Color(atta: 0x463B50))],
        angleDeg: 155, ink: Color(atta: 0xF2EDE6),
        lightInk: true, ruleChampagne: false, hairline: false
    )

    static let onyx = WidgetTheme(
        id: "onyx", displayName: "Onyx",
        stops: [(0, Color(atta: 0x2B2627)), (0.52, Color(atta: 0x211D1E)), (1, Color(atta: 0x151213))],
        angleDeg: 150, ink: Color(atta: 0xEDE6DC),
        lightInk: true, ruleChampagne: true, hairline: true
    )

    static let sageField = WidgetTheme(
        id: "sage", displayName: "Sage Field",
        stops: [(0, Color(atta: 0xCBD4C6)), (0.52, Color(atta: 0xB4C1B2)), (1, Color(atta: 0x9AAE9C))],
        angleDeg: 160, ink: Color(atta: 0x1E2A20),
        lightInk: false, ruleChampagne: false, hairline: false
    )

    static let clay = WidgetTheme(
        id: "clay", displayName: "Clay",
        stops: [(0, Color(atta: 0xE8CFC6)), (0.52, Color(atta: 0xDBB8AE)), (1, Color(atta: 0xC99C94))],
        angleDeg: 158, ink: Color(atta: 0x35211D),
        lightInk: false, ruleChampagne: false, hairline: false
    )

    static let deepWater = WidgetTheme(
        id: "water", displayName: "Deep Water",
        stops: [(0, Color(atta: 0x356E68)), (0.52, Color(atta: 0x2A5C57)), (1, Color(atta: 0x1F4B47))],
        angleDeg: 152, ink: Color(atta: 0xE6F0EC),
        lightInk: true, ruleChampagne: false, hairline: false
    )

    static let rosewood = WidgetTheme(
        id: "rosewood", displayName: "Rosewood",
        stops: [(0, Color(atta: 0xF2DEDC)), (0.52, Color(atta: 0xE5C6C4)), (1, Color(atta: 0xD5ABA9))],
        angleDeg: 158, ink: Color(atta: 0x33211F),
        lightInk: false, ruleChampagne: false, hairline: false
    )

    static let midnight = WidgetTheme(
        id: "midnight", displayName: "Midnight",
        stops: [(0, Color(atta: 0x2A3240)), (0.52, Color(atta: 0x212837)), (1, Color(atta: 0x171D2B))],
        angleDeg: 152, ink: Color(atta: 0xE8ECF2),
        lightInk: true, ruleChampagne: false, hairline: false
    )

    static let honey = WidgetTheme(
        id: "honey", displayName: "Honey",
        stops: [(0, Color(atta: 0xF6E8CE)), (0.52, Color(atta: 0xEFD9AF)), (1, Color(atta: 0xE4C48F))],
        angleDeg: 162, ink: Color(atta: 0x2E2414),
        lightInk: false, ruleChampagne: false, hairline: false
    )

    static let all = [dawn, mist, linen, dusk, onyx, sageField, clay, deepWater, rosewood, midnight, honey]

    static let defaultId = "dawn"

    /// The free tier keeps Linen only; the widget and other themes are the upgrade.
    static let freeThemeId = "linen"

    static func byId(_ id: String?) -> WidgetTheme {
        all.first { $0.id == id } ?? dawn
    }
}
