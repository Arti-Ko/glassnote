import Foundation

enum AppConfig {
    /// WhisperKit model candidates, best first. large-v3-v20240930 is large-v3-turbo
    /// in the argmaxinc/whisperkit-coreml naming; fallbacks cover older repo layouts.
    static let modelCandidates = ["large-v3-v20240930", "large-v3_turbo", "large-v3"]

    static let notesRootDefault = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Glassnote", isDirectory: true)

    static let noteFolderDateFormat = "yyyy-MM-dd_HH-mm-ss"
    static let titleWordCount = 8
    static let audioFileName = "audio.m4a"
    static let noteFileName = "note.json"
    static let transcriptFileName = "transcript.md"
    static let indexFileName = ".index.db"

    /// Ключ UserDefaults для выбранного языка распознавания.
    static let languageKey = "recordingLanguage"
}
