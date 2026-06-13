import XCTest
@testable import Glassnote

// MARK: - Хелперы

private func makeNote(
    id: UUID = UUID(),
    title: String = "Тестовая заметка",
    segments: [NoteSegment] = [
        NoteSegment(start: 0, end: 2.5, text: "привет тестовая заметка", speaker: nil)
    ]
) -> Note {
    Note(
        id: id,
        createdAt: Date(timeIntervalSince1970: 1_780_000_000),
        durationSec: 2.5,
        language: "ru",
        model: "test-model",
        title: title,
        edited: false,
        segments: segments
    )
}

// MARK: - NoteStore

final class NoteStoreTests: XCTestCase {
    private var tempRoot: URL!
    private var store: NoteStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("glassnote-tests-\(UUID().uuidString)")
        store = try NoteStore(rootURL: tempRoot)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testSaveAndLoadRoundtrip() throws {
        // Arrange
        let note = makeNote()
        let folder = try store.createNoteFolder(for: note.createdAt)

        // Act
        try store.save(note: note, transcript: note.plainText, in: folder)
        let loaded = store.loadAll()

        // Assert
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].note, note)
        XCTAssertEqual(loaded[0].transcript, "привет тестовая заметка")
    }

    func testUpdateTranscriptSetsEditedAndPreservesSegments() throws {
        // Arrange
        let note = makeNote()
        let folder = try store.createNoteFolder(for: note.createdAt)
        let stored = try store.save(note: note, transcript: note.plainText, in: folder)

        // Act
        let updated = try store.updateTranscript("исправленный текст", for: stored)

        // Assert
        XCTAssertTrue(updated.note.edited)
        XCTAssertEqual(updated.transcript, "исправленный текст")
        XCTAssertEqual(updated.note.segments, note.segments, "оригинальные сегменты не должны затираться")
        XCTAssertEqual(updated.note.title, "исправленный текст")
    }

    func testDeleteRemovesFolder() throws {
        // Arrange
        let note = makeNote()
        let folder = try store.createNoteFolder(for: note.createdAt)
        let stored = try store.save(note: note, transcript: "x", in: folder)

        // Act
        try store.delete(stored)

        // Assert
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testFolderCollisionGetsSuffix() throws {
        // Arrange: две заметки в одну и ту же секунду
        let date = Date(timeIntervalSince1970: 1_780_000_000)

        // Act
        let first = try store.createNoteFolder(for: date)
        let second = try store.createNoteFolder(for: date)

        // Assert
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(second.lastPathComponent.hasSuffix("-2"))
    }
}

// MARK: - Заголовок заметки

final class NoteTitleTests: XCTestCase {
    func testEmptyTextGivesPlaceholder() {
        XCTAssertEqual(Note.makeTitle(from: "   \n "), "Без названия")
    }

    func testShortTextStaysAsIs() {
        XCTAssertEqual(Note.makeTitle(from: "купить молоко"), "купить молоко")
    }

    func testLongTextTruncatesWithEllipsis() {
        let text = "один два три четыре пять шесть семь восемь девять десять"
        let title = Note.makeTitle(from: text, maxWords: 8)
        XCTAssertEqual(title, "один два три четыре пять шесть семь восемь…")
    }
}

// MARK: - Очистка токенов Whisper

final class TranscriberCleanTextTests: XCTestCase {
    func testRemovesSpecialTokens() {
        XCTAssertEqual(
            Transcriber.cleanText("<|ru|><|transcribe|> Привет, мир <|0.00|>"),
            "Привет, мир"
        )
    }

    func testPlainTextUntouched() {
        XCTAssertEqual(Transcriber.cleanText("  обычный текст "), "обычный текст")
    }
}

// MARK: - Поиск

final class SearchIndexTests: XCTestCase {
    private var tempDB: URL!
    private var index: SearchIndex!

    override func setUpWithError() throws {
        tempDB = FileManager.default.temporaryDirectory
            .appendingPathComponent("glassnote-index-\(UUID().uuidString).db")
        index = try SearchIndex(fileURL: tempDB)
    }

    override func tearDownWithError() throws {
        index = nil
        try? FileManager.default.removeItem(at: tempDB)
    }

    private func storedNote(id: UUID, transcript: String) -> StoredNote {
        StoredNote(
            note: makeNote(id: id, title: Note.makeTitle(from: transcript)),
            folderURL: FileManager.default.temporaryDirectory,
            transcript: transcript
        )
    }

    func testSearchFindsRussianWord() throws {
        // Arrange
        let target = UUID()
        try index.upsert(storedNote(id: target, transcript: "обсудили архитектуру синхронизации"))
        try index.upsert(storedNote(id: UUID(), transcript: "список покупок на неделю"))

        // Act
        let ids = index.search("синхронизации")

        // Assert
        XCTAssertEqual(ids, [target])
    }

    func testPrefixSearchMatches() throws {
        // Arrange
        let target = UUID()
        try index.upsert(storedNote(id: target, transcript: "встреча с инвестором в пятницу"))

        // Act: префикс слова
        let ids = index.search("инвест")

        // Assert
        XCTAssertEqual(ids, [target])
    }

    func testRemoveDropsNoteFromResults() throws {
        // Arrange
        let id = UUID()
        try index.upsert(storedNote(id: id, transcript: "уникальное слово гиппопотам"))

        // Act
        try index.remove(id)

        // Assert
        XCTAssertTrue(index.search("гиппопотам").isEmpty)
    }

    func testQuotesInQueryDoNotCrash() throws {
        // Arrange
        try index.upsert(storedNote(id: UUID(), transcript: "просто текст"))

        // Act + Assert: кавычки экранируются, запрос не роняет FTS
        XCTAssertNoThrow(_ = index.search("\"текст\""))
    }
}
