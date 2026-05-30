import CoreText
import SwiftUI

struct DraftVisualBadge: View {
    let iconName: String
    let colorHex: String
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.18))

            FontAwesomeIcon(name: iconName, size: size * 0.43)
                .foregroundStyle(Color(hex: colorHex))
        }
        .frame(width: size, height: size)
    }
}

struct FontAwesomeIcon: View {
    let name: String
    var size: CGFloat = 16

    init(name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
        FontAwesomeFontLoader.registerIfNeeded()
    }

    var body: some View {
        Text(glyph)
            .font(.custom(FontAwesomeFontLoader.postScriptName, fixedSize: size))
            .accessibilityHidden(true)
    }

    private var glyph: String {
        Self.glyphs[name] ?? Self.glyphs["tag"] ?? ""
    }

    private static let glyphs = [
        "bag-shopping": "\u{f290}",
        "basket-shopping": "\u{f291}",
        "book": "\u{f02d}",
        "box-archive": "\u{f187}",
        "briefcase": "\u{f0b1}",
        "building-columns": "\u{f19c}",
        "burger": "\u{f805}",
        "bus": "\u{f207}",
        "car": "\u{f1b9}",
        "cart-shopping": "\u{f07a}",
        "chart-pie": "\u{f200}",
        "circle-dollar-to-slot": "\u{f4b9}",
        "circle-question": "\u{f059}",
        "coins": "\u{f51e}",
        "credit-card": "\u{f09d}",
        "ellipsis": "\u{f141}",
        "file-invoice-dollar": "\u{f571}",
        "file-lines": "\u{f15c}",
        "gamepad": "\u{f11b}",
        "gas-pump": "\u{f52f}",
        "gift": "\u{f06b}",
        "graduation-cap": "\u{f19d}",
        "heart-pulse": "\u{f21e}",
        "house": "\u{f015}",
        "kit-medical": "\u{f479}",
        "landmark": "\u{f66f}",
        "mobile-screen-button": "\u{f3cd}",
        "money-bill": "\u{f0d6}",
        "money-bill-wave": "\u{f53a}",
        "money-check-dollar": "\u{f53d}",
        "mug-saucer": "\u{f0f4}",
        "palette": "\u{f53f}",
        "paw": "\u{f1b0}",
        "phone": "\u{f095}",
        "piggy-bank": "\u{f4d3}",
        "plane": "\u{f072}",
        "receipt": "\u{f543}",
        "sack-dollar": "\u{f81d}",
        "shield-halved": "\u{f3ed}",
        "shirt": "\u{f553}",
        "store": "\u{f54e}",
        "tag": "\u{f02b}",
        "train-subway": "\u{f239}",
        "truck-fast": "\u{f48b}",
        "utensils": "\u{f2e7}",
        "wallet": "\u{f555}",
        "wifi": "\u{f1eb}"
    ]
}

private enum FontAwesomeFontLoader {
    static let postScriptName = "FontAwesome7Free-Solid"

    static func registerIfNeeded() {
        _ = registerOnce
    }

    private static let registerOnce: Void = {
        guard let fontURL = fontURL() else { return }
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }()

    private static func fontURL() -> URL? {
        let bundle = Bundle.main
        let resourceName = "FontAwesome7Free-Solid-900"

        return bundle.url(
            forResource: resourceName,
            withExtension: "otf",
            subdirectory: "Resources/Fonts"
        )
        ?? bundle.url(forResource: resourceName, withExtension: "otf")
    }
}

extension Color {
    init(hex: String) {
        let normalizedHex = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var value: UInt64 = 0
        Scanner(string: normalizedHex).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch normalizedHex.count {
        case 6:
            red = (value & 0xFF0000) >> 16
            green = (value & 0x00FF00) >> 8
            blue = value & 0x0000FF
        default:
            red = 0xF6
            green = 0xC3
            blue = 0x43
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}
