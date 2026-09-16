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
    case bn
    case ru
    case id
    case ms
    case ja
    case ko
    case vi
    case sw

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
        case .bn: return "বাংলা"
        case .ru: return "Русский"
        case .id: return "Bahasa Indonesia"
        case .ms: return "Bahasa Melayu"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .vi: return "Tiếng Việt"
        case .sw: return "Kiswahili"
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
        case .bn: return "🇧🇩"
        case .ru: return "🇷🇺"
        case .id: return "🇮🇩"
        case .ms: return "🇲🇾"
        case .ja: return "🇯🇵"
        case .ko: return "🇰🇷"
        case .vi: return "🇻🇳"
        case .sw: return "🇹🇿"
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
        case .bn: return "bn_BD"
        case .ru: return "ru_RU"
        case .id: return "id_ID"
        case .ms: return "ms_MY"
        case .ja: return "ja_JP"
        case .ko: return "ko_KR"
        case .vi: return "vi_VN"
        case .sw: return "sw_TZ"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }
}
