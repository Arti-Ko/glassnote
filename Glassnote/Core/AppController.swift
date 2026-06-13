import AppKit
import Combine

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    enum Phase { case idle, recording, transcribing }

    @Published private(set) var notes: [StoredNote] = []
    @Published private(set) var isRecording = false
    @Published private(set) var transcribingCount = 0
    @Published var lastError: String?

    let recorder = AudioRecorder()
    let transcriber = Transcriber()

    private(set) var store: NoteStore?
    private var index: SearchIndex?
    private let panel = RecordingPanelController()
    private var recordingStartedAt = Date()

    var phase: Phase {
        if isRecording { return .recording }
        if transcribingCount > 0 { return .transcribing }
        return .idle
    }

    private init() {
        do {
            let store = try NoteStore()
            self.store = store
            let index = try SearchIndex(
                fileURL: store.rootURL.appendingPathComponent(AppConfig.indexFileName)
            )
            self.index = index
            let loaded = store.loadAll()
            notes = loaded
            try index.rebuild(from: loaded)
        } catch {
            lastError = "Не удалось открыть хранилище заметок: \(error.localizedDescription)"
        }
        Task { await transcriber.prepare() }
    }

    // MARK: - Запись

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    /// Прячет панель, не прерывая запись.
    func minimizePanel() {
        panel.hide()
    }

    private func startRecording() {
        // Состояние занимаем сразу: повторный хоткей до завершения await
        // не должен запустить вторую параллельную запись.
        isRecording = true
        Task {
            guard await AudioRecorder.requestPermission() else {
                isRecording = false
                lastError = "Нет доступа к микрофону. Разрешите его в Системных настройках → Конфиденциальность."
                return
            }
            guard isRecording else { return } // отменили повторным нажатием, пока ждали разрешение
            do {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("m4a")
                try recorder.start(to: tempURL)
                recordingStartedAt = Date()
                SoundPlayer.playStart()
                panel.show(controller: self)
            } catch {
                isRecording = false
                lastError = error.localizedDescription
            }
        }
    }

    private func stopRecording() {
        defer {
            isRecording = false
            panel.hide()
        }
        guard let result = recorder.stop() else { return }
        SoundPlayer.playStop()
        let startedAt = recordingStartedAt
        Task { await finishNote(tempAudioURL: result.url, duration: result.duration, date: startedAt) }
    }

    private func finishNote(tempAudioURL: URL, duration: TimeInterval, date: Date) async {
        guard let store, let index else { return }
        transcribingCount += 1
        defer { transcribingCount -= 1 }

        // Порядок: папка → note.json → аудио. Заметка не может оказаться
        // на диске без метаданных (иначе loadAll молча её пропустит).
        var folder: URL?
        do {
            let created = try store.createNoteFolder(for: date)
            folder = created

            var note = Note(
                id: UUID(),
                createdAt: date,
                durationSec: duration,
                language: nil,
                model: transcriber.activeModelName ?? "",
                title: "Расшифровывается…",
                edited: false,
                segments: []
            )
            var stored = try store.save(note: note, transcript: "", in: created)
            insertOrReplace(stored)

            let audioURL = created.appendingPathComponent(AppConfig.audioFileName)
            try FileManager.default.moveItem(at: tempAudioURL, to: audioURL)

            let result = try await transcriber.transcribe(audioURL: audioURL)
            note.segments = result.segments
            note.language = result.language
            note.model = transcriber.activeModelName ?? note.model
            note.title = Note.makeTitle(from: note.plainText)
            stored = try store.save(note: note, transcript: note.plainText, in: created)
            insertOrReplace(stored)
            try index.upsert(stored)
        } catch {
            // Папка без аудио бесполезна — убираем, чтобы не плодить пустые заметки.
            if let folder,
               !FileManager.default.fileExists(
                   atPath: folder.appendingPathComponent(AppConfig.audioFileName).path
               ) {
                try? FileManager.default.removeItem(at: folder)
                notes.removeAll { $0.folderURL == folder }
                lastError = "Заметка не сохранилась: \(error.localizedDescription)"
            } else {
                lastError = "Расшифровка не удалась: \(error.localizedDescription). Аудио сохранено."
            }
        }
    }

    // MARK: - Действия из UI

    func updateTranscript(_ text: String, for stored: StoredNote) {
        guard let store, let index else { return }
        // Заметку могли удалить, пока работал debounce автосохранения.
        guard notes.contains(where: { $0.id == stored.id }) else { return }
        do {
            let updated = try store.updateTranscript(text, for: stored)
            insertOrReplace(updated)
            try index.upsert(updated)
        } catch {
            lastError = "Не удалось сохранить правку: \(error.localizedDescription)"
        }
    }

    func delete(_ stored: StoredNote) {
        do {
            try store?.delete(stored)
            try index?.remove(stored.id)
            notes.removeAll { $0.id == stored.id }
        } catch {
            lastError = "Не удалось удалить заметку: \(error.localizedDescription)"
        }
    }

    func filteredNotes(query: String) -> [StoredNote] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index else { return notes }
        let ids = index.search(trimmed)
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    func markdown(for stored: StoredNote) -> String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        return "# \(stored.note.title)\n\n_\(df.string(from: stored.note.createdAt))_\n\n\(stored.transcript)\n"
    }

    private func insertOrReplace(_ stored: StoredNote) {
        if let i = notes.firstIndex(where: { $0.id == stored.id }) {
            notes[i] = stored
        } else {
            notes.append(stored)
            notes.sort { $0.note.createdAt > $1.note.createdAt }
        }
    }
}
