import Foundation
import WhisperKit

@MainActor
final class Transcriber: ObservableObject {
    enum ModelState: Equatable {
        case notLoaded
        case loading(String)
        case ready(String)
        case failed(String)
    }

    @Published private(set) var modelState: ModelState = .notLoaded
    private var whisperKit: WhisperKit?

    var activeModelName: String? {
        if case .ready(let name) = modelState { return name }
        return nil
    }

    enum TranscriberError: LocalizedError {
        case modelNotReady
        var errorDescription: String? { "Модель распознавания не загружена" }
    }

    /// Скачивает (при первом запуске) и инициализирует модель.
    /// Кандидаты перебираются по порядку — выживаем при смене имён в репозитории моделей.
    func prepare() async {
        guard whisperKit == nil else { return }
        // Под XCTest host-приложение не должно тянуть 1.6 ГБ модели.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        for candidate in AppConfig.modelCandidates {
            modelState = .loading(candidate)
            do {
                let kit = try await WhisperKit(model: candidate)
                whisperKit = kit
                modelState = .ready(candidate)
                return
            } catch {
                continue
            }
        }
        modelState = .failed("Не удалось загрузить модель Whisper (проверьте интернет для первой загрузки)")
    }

    func transcribe(audioURL: URL) async throws -> (segments: [NoteSegment], language: String?) {
        if whisperKit == nil { await prepare() }
        guard let kit = whisperKit else { throw TranscriberError.modelNotReady }

        let options = DecodingOptions(task: .transcribe) // язык определяется автоматически
        let results = try await kit.transcribe(audioPath: audioURL.path, decodeOptions: options)

        var segments: [NoteSegment] = []
        for result in results {
            for seg in result.segments {
                let text = Self.cleanText(seg.text)
                guard !text.isEmpty else { continue }
                segments.append(NoteSegment(
                    start: Double(seg.start),
                    end: Double(seg.end),
                    text: text,
                    speaker: nil
                ))
            }
        }
        return (segments, results.first?.language)
    }

    /// Убирает служебные токены Whisper вида <|ru|>, <|transcribe|>, <|0.00|>.
    nonisolated static func cleanText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
