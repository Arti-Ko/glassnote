import Foundation

struct NoteSegment: Codable, Equatable {
    var start: Double
    var end: Double
    var text: String
    /// Заполняется в v2 диаризацией (SpeakerKit); в v1 всегда nil.
    var speaker: String?
}

struct Note: Codable, Identifiable, Equatable {
    var id: UUID
    var createdAt: Date
    var durationSec: Double
    var language: String?
    var model: String
    var title: String
    var edited: Bool
    var segments: [NoteSegment]
}

extension Note {
    static func makeTitle(from text: String, maxWords: Int = AppConfig.titleWordCount) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        guard !words.isEmpty else { return "Без названия" }
        let title = words.prefix(maxWords).joined(separator: " ")
        return words.count > maxWords ? title + "…" : title
    }

    var plainText: String {
        segments.map { $0.text.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
