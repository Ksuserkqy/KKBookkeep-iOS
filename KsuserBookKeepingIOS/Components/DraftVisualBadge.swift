import CoreText
import Foundation
import SwiftUI
import UIKit

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
            .font(.custom(fontName, fixedSize: size))
            .accessibilityHidden(true)
    }

    private var glyph: String {
        FontAwesomeIconCatalog.glyph(for: name)
    }

    private var fontName: String {
        FontAwesomeIconCatalog.fontName(for: name)
    }
}

struct FontAwesomeIconMetadata: Codable, Identifiable {
    var id: String { name }

    let name: String
    let unicode: String
    let label: String
    let style: FontAwesomeIconStyle
    let terms: [String]
    let categories: [String]

    init(
        name: String,
        unicode: String,
        label: String,
        style: FontAwesomeIconStyle,
        terms: [String],
        categories: [String] = []
    ) {
        self.name = name
        self.unicode = unicode
        self.label = label
        self.style = style
        self.terms = terms
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        unicode = try container.decode(String.self, forKey: .unicode)
        label = try container.decode(String.self, forKey: .label)
        style = try container.decodeIfPresent(FontAwesomeIconStyle.self, forKey: .style) ?? .solid
        terms = try container.decodeIfPresent([String].self, forKey: .terms) ?? []
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
    }

    var glyph: String {
        guard let scalarValue = UInt32(unicode, radix: 16), let scalar = UnicodeScalar(scalarValue) else {
            return FontAwesomeIconCatalog.fallbackGlyph
        }

        return String(Character(scalar))
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return true }

        if name.localizedCaseInsensitiveContains(normalizedQuery) {
            return true
        }

        if label.localizedCaseInsensitiveContains(normalizedQuery) {
            return true
        }

        if terms.contains(where: { $0.localizedCaseInsensitiveContains(normalizedQuery) }) {
            return true
        }

        return FontAwesomeIconCatalog.searchAliases(for: name).contains { alias in
            let normalizedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            return normalizedAlias.localizedCaseInsensitiveContains(normalizedQuery)
                || normalizedQuery.localizedCaseInsensitiveContains(normalizedAlias)
        }
    }
}

struct FontAwesomeIconCategoryMetadata: Codable, Identifiable {
    let id: String
    let label: String
    let iconCount: Int
}

enum FontAwesomeIconCatalog {
    static let allCategoryId = ""
    static let brandCategoryId = "__brands"
    static let fallbackName = "tag"
    static let fallbackGlyph = "\u{f02b}"

    static func glyph(for name: String) -> String {
        glyphs[name] ?? allIconsByName[name]?.glyph ?? fallbackGlyph
    }

    static func fontName(for name: String) -> String {
        allIconsByName[name]?.style.fontName ?? FontAwesomeIconStyle.solid.fontName
    }

    static var allIcons: [FontAwesomeIconMetadata] {
        loadedIcons
    }

    static var allCategories: [FontAwesomeIconCategoryMetadata] {
        loadedCategories
    }

    private static let loadedIcons = loadAllIcons()

    private static let loadedCategories = loadAllCategories()

    private static let allIconsByName = Dictionary(uniqueKeysWithValues: loadedIcons.map { ($0.name, $0) })

    static func searchAliases(for name: String) -> [String] {
        localizedSearchAliases[name] ?? []
    }

    private static func loadAllIcons() -> [FontAwesomeIconMetadata] {
        guard
            let url = Bundle.main.url(
                forResource: "free-icons-7.2.0",
                withExtension: "json",
                subdirectory: "Resources/FontAwesome"
            )
            ?? Bundle.main.url(forResource: "free-icons-7.2.0", withExtension: "json")
            ?? Bundle.main.url(forResource: "free-solid-icons-7.2.0", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let icons = try? JSONDecoder().decode([FontAwesomeIconMetadata].self, from: data)
        else {
            return glyphs.map { name, unicode in
                FontAwesomeIconMetadata(name: name, unicode: unicode.hexCodePoint, label: name, style: .solid, terms: [])
            }
            .sorted { $0.name < $1.name }
        }

        return icons
    }

    private static func loadAllCategories() -> [FontAwesomeIconCategoryMetadata] {
        guard
            let url = Bundle.main.url(
                forResource: "free-icon-categories-7.2.0",
                withExtension: "json",
                subdirectory: "Resources/FontAwesome"
            )
            ?? Bundle.main.url(forResource: "free-icon-categories-7.2.0", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let categories = try? JSONDecoder().decode([FontAwesomeIconCategoryMetadata].self, from: data)
        else {
            let categoryIds = Set(loadedIcons.flatMap(\.categories))

            return categoryIds
                .map { FontAwesomeIconCategoryMetadata(id: $0, label: $0, iconCount: 0) }
                .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        }

        return categories
    }

    private static let localizedSearchAliases = [
        "alipay": ["支付宝", "支付宝钱包"],
        "apple-pay": ["苹果支付"],
        "credit-card": ["银行卡", "信用卡"],
        "money-bill": ["现金"],
        "money-bill-wave": ["现金"],
        "qq": ["腾讯", "腾讯 QQ"],
        "wallet": ["钱包", "电子钱包"],
        "weixin": ["微信", "微信支付", "WeChat"]
    ]

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

enum FontAwesomeIconStyle: String, Codable {
    case solid
    case brands

    var fontName: String {
        switch self {
        case .solid:
            return "FontAwesome7Free-Solid"
        case .brands:
            return "FontAwesome7Brands-Regular"
        }
    }
}

private extension String {
    var hexCodePoint: String {
        unicodeScalars.first.map { String($0.value, radix: 16) } ?? "f02b"
    }
}

private enum FontAwesomeFontLoader {
    static func registerIfNeeded() {
        _ = registerOnce
    }

    private static let registerOnce: Void = {
        fontURLs().forEach { fontURL in
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }()

    private static func fontURLs() -> [URL] {
        let bundle = Bundle.main
        let resourceNames = [
            "FontAwesome7Free-Solid-900",
            "FontAwesome7Brands-Regular-400"
        ]

        return resourceNames.compactMap { resourceName in
            bundle.url(
                forResource: resourceName,
                withExtension: "otf",
                subdirectory: "Resources/Fonts"
            )
            ?? bundle.url(forResource: resourceName, withExtension: "otf")
        }
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

    var hexString: String {
        let resolvedColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#F6C343"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
