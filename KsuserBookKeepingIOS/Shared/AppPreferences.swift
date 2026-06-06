import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system:
            return "settings.language.system"
        case .simplifiedChinese:
            return "settings.language.zhHans"
        case .english:
            return "settings.language.en"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.current.identifier
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system:
            return "settings.theme.system"
        case .light:
            return "settings.theme.light"
        case .dark:
            return "settings.theme.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppLocalization {
    static var localeIdentifier: String {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app.language") ?? AppLanguage.system.rawValue)?
            .localeIdentifier ?? Locale.current.identifier
    }

    static var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    static func string(_ key: String, comment: String = "") -> String {
        let language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app.language") ?? AppLanguage.system.rawValue) ?? .system
        guard language != .system else {
            return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        }

        guard
            let path = Bundle.main.path(forResource: language.localeIdentifier, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }
}
