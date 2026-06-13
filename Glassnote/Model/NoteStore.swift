import Foundation

struct StoredNote: Identifiable, Equatable {
    var note: Note
    var folderURL: URL
    var transcript: String

    var id: UUID { note.id }
    var audioURL: URL { folderURL.appendingPathComponent(AppConfig.audioFileName) }
}

enum NoteStoreError: Error {
    case folderCollision(URL)
}

/// Файлы — источник истины. Каждая заметка — папка `yyyy-MM-dd_HH-mm-ss/`
/// с audio.m4a, note.json и transcript.md внутри.
final class NoteStore {
    let rootURL: URL
    private let fm = FileManager.default

    private static let folderNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = AppConfig.noteFolderDateFormat
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(rootURL: URL = AppConfig.notesRootDefault) throws {
        self.rootURL = rootURL
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func loadAll() -> [StoredNote] {
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let notes = entries.compactMap { folder -> StoredNote? in
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return nil
            }
            return load(from: folder)
        }
        return notes.sorted { $0.note.createdAt > $1.note.createdAt }
    }

    func load(from folder: URL) -> StoredNote? {
        let noteURL = folder.appendingPathComponent(AppConfig.noteFileName)
        guard let data = try? Data(contentsOf: noteURL),
              let note = try? Self.decoder.decode(Note.self, from: data) else { return nil }
        let transcriptURL = folder.appendingPathComponent(AppConfig.transcriptFileName)
        let transcript = (try? String(contentsOf: transcriptURL, encoding: .utf8)) ?? note.plainText
        return StoredNote(note: note, folderURL: folder, transcript: transcript)
    }

    /// Создаёт уникальную папку заметки; при коллизии имени добавляет -2, -3…
    func createNoteFolder(for date: Date) throws -> URL {
        let base = Self.folderNameFormatter.string(from: date)
        for attempt in 0..<100 {
            let name = attempt == 0 ? base : "\(base)-\(attempt + 1)"
            let url = rootURL.appendingPathComponent(name, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            }
        }
        throw NoteStoreError.folderCollision(rootURL)
    }

    @discardableResult
    func save(note: Note, transcript: String, in folder: URL) throws -> StoredNote {
        let data = try Self.encoder.encode(note)
        try data.write(to: folder.appendingPathComponent(AppConfig.noteFileName), options: .atomic)
        try transcript.write(
            to: folder.appendingPathComponent(AppConfig.transcriptFileName),
            atomically: true,
            encoding: .utf8
        )
        return StoredNote(note: note, folderURL: folder, transcript: transcript)
    }

    /// Правка текста: transcript.md перезаписывается, edited=true,
    /// оригинальные сегменты в note.json не трогаются.
    func updateTranscript(_ text: String, for stored: StoredNote) throws -> StoredNote {
        var note = stored.note
        note.edited = true
        note.title = Note.makeTitle(from: text)
        return try save(note: note, transcript: text, in: stored.folderURL)
    }

    func delete(_ stored: StoredNote) throws {
        try fm.removeItem(at: stored.folderURL)
    }
}
