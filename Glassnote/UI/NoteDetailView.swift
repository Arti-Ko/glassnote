import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

struct NoteDetailView: View {
    @EnvironmentObject private var controller: AppController
    var stored: StoredNote

    @State private var text = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            Divider()
            AudioPlayerView(url: stored.audioURL)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            Divider()
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(12)
        }
        .navigationTitle(stored.note.title)
        .onAppear { text = stored.transcript }
        .onChange(of: stored.id) { _, _ in text = stored.transcript }
        .onChange(of: text) { _, newValue in scheduleSave(newValue) }
        .onDisappear { saveTask?.cancel() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(controller.markdown(for: current), forType: .string)
                } label: {
                    Label("Копировать", systemImage: "doc.on.doc")
                }
                .help("Скопировать как Markdown")

                Button {
                    exportMarkdown()
                } label: {
                    Label("Экспорт", systemImage: "square.and.arrow.up")
                }
                .help("Сохранить в .md файл")

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Удалить заметку «\(stored.note.title)»?",
            isPresented: $confirmDelete
        ) {
            Button("Удалить (аудио и текст)", role: .destructive) {
                controller.delete(current)
            }
        } message: {
            Text("Папка заметки будет удалена с диска.")
        }
    }

    /// Свежая версия заметки из контроллера — `stored` может устареть после автосохранения.
    private var current: StoredNote {
        controller.notes.first(where: { $0.id == stored.id }) ?? stored
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(stored.note.createdAt, format: .dateTime.day().month(.wide).year().hour().minute())
                .foregroundStyle(.secondary)
            Text("·").foregroundStyle(.secondary)
            Text(Format.mmss(stored.note.durationSec))
                .foregroundStyle(.secondary)
            if let lang = stored.note.language, !lang.isEmpty {
                Text(lang.uppercased())
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            if stored.note.edited {
                Label("изменено", systemImage: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.callout)
    }

    private func scheduleSave(_ newValue: String) {
        guard newValue != current.transcript else { return }
        saveTask?.cancel()
        let snapshot = current
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            guard controller.notes.contains(where: { $0.id == snapshot.id }) else { return }
            controller.updateTranscript(newValue, for: snapshot)
        }
    }

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = stored.note.title.replacingOccurrences(of: "/", with: "-") + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try controller.markdown(for: current).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            controller.lastError = "Экспорт не удался: \(error.localizedDescription)"
        }
    }
}

// MARK: - Плеер

@MainActor
final class PlayerModel: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published private(set) var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stopTimer()
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        duration = player?.duration ?? 0
        progress = 0
        isPlaying = false
    }

    func toggle() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    func seek(to fraction: Double) {
        guard let player, duration > 0 else { return }
        player.currentTime = fraction * duration
        progress = fraction
    }

    private func tick() {
        guard let player else { return }
        progress = duration > 0 ? player.currentTime / duration : 0
        if !player.isPlaying && isPlaying {
            isPlaying = false
            progress = 0
            stopTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct AudioPlayerView: View {
    let url: URL
    @StateObject private var model = PlayerModel()

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.toggle()
            } label: {
                Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
            }
            .buttonStyle(.plain)

            Text(Format.mmss(model.progress * model.duration))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { model.progress },
                    set: { model.seek(to: $0) }
                ),
                in: 0...1
            )

            Text(Format.mmss(model.duration))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .onAppear { model.load(url: url) }
        .onChange(of: url) { _, newURL in model.load(url: newURL) }
    }
}
