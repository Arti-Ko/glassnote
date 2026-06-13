import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// FTS5-кэш поиска поверх файлового хранилища. Файл лежит в корне заметок
/// скрытым (.index.db) и целиком перестраивается из папок при запуске.
final class SearchIndex {
    private var db: OpaquePointer?

    init(fileURL: URL) throws {
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            throw SearchIndexError.openFailed
        }
        try exec("""
        CREATE VIRTUAL TABLE IF NOT EXISTS notes USING fts5(
            id UNINDEXED, title, body,
            tokenize = 'unicode61 remove_diacritics 2'
        );
        """)
    }

    deinit { sqlite3_close_v2(db) }

    enum SearchIndexError: Error { case openFailed, queryFailed(String) }

    /// Полная перестройка в одной транзакции: при сбое посредине
    /// прежний индекс откатывается, а не остаётся полупустым.
    func rebuild(from notes: [StoredNote]) throws {
        try exec("BEGIN IMMEDIATE;")
        do {
            try exec("DELETE FROM notes;")
            for stored in notes {
                try upsert(stored)
            }
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    func upsert(_ stored: StoredNote) throws {
        try remove(stored.note.id)
        let sql = "INSERT INTO notes (id, title, body) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchIndexError.queryFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, stored.note.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, stored.note.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, stored.transcript, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SearchIndexError.queryFailed(lastError)
        }
    }

    func remove(_ id: UUID) throws {
        let sql = "DELETE FROM notes WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchIndexError.queryFailed(lastError)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SearchIndexError.queryFailed(lastError)
        }
    }

    /// Возвращает id заметок по релевантности. Пользовательский ввод
    /// экранируется: каждое слово оборачивается в кавычки с префиксным `*`.
    func search(_ query: String) -> [UUID] {
        let terms = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { "\"\($0.replacingOccurrences(of: "\"", with: ""))\"*" }
        guard !terms.isEmpty else { return [] }
        let match = terms.joined(separator: " ")

        let sql = "SELECT id FROM notes WHERE notes MATCH ? ORDER BY bm25(notes);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, match, -1, SQLITE_TRANSIENT)

        var ids: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0),
               let id = UUID(uuidString: String(cString: cString)) {
                ids.append(id)
            }
        }
        return ids
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK else {
            let message = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw SearchIndexError.queryFailed(message)
        }
    }

    private var lastError: String {
        sqlite3_errmsg(db).map { String(cString: $0) } ?? "unknown"
    }
}
