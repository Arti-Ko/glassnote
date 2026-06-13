import Foundation

/// Язык распознавания. `auto` включает автоопределение Whisper,
/// явный выбор форсирует язык — иначе WhisperKit по умолчанию уходит в английский.
enum RecordingLanguage: String, CaseIterable, Identifiable {
    case auto
    case ru
    case en

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Автоопределение"
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    /// Код языка для WhisperKit; `nil` означает автоопределение.
    var whisperCode: String? {
        self == .auto ? nil : rawValue
    }

    /// Текущий выбор пользователя из UserDefaults (по умолчанию автоопределение).
    static var current: RecordingLanguage {
        let raw = UserDefaults.standard.string(forKey: AppConfig.languageKey)
        return raw.flatMap(RecordingLanguage.init(rawValue:)) ?? .auto
    }
}
