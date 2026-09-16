import Foundation

/// A supported UI language (code, endonym, flag emoji, locale).
enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case tr
    case de
    case es
    case pt
    case fr
    case it
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case hi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .pt: return "Português"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .hi: return "हिन्दी"
        }
    }

    var flag: String {
        switch self {
        case .en: return "🇺🇸"
        case .tr: return "🇹🇷"
        case .de: return "🇩🇪"
        case .es: return "🇪🇸"
        case .pt: return "🇵🇹"
        case .fr: return "🇫🇷"
        case .it: return "🇮🇹"
        case .zhHans, .zhHant: return "🇨🇳"
        case .hi: return "🇮🇳"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .en: return "en"
        case .tr: return "tr_TR"
        case .de: return "de_DE"
        case .es: return "es_ES"
        case .pt: return "pt_PT"
        case .fr: return "fr_FR"
        case .it: return "it_IT"
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .hi: return "hi_IN"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }
}
