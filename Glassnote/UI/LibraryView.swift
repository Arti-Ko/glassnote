import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var controller: AppController
    @State private var query = ""
    @State private var selectedID: UUID?

    private var filtered: [StoredNote] {
        controller.filteredNotes(query: query)
    }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $selectedID) { stored in
                NoteRow(stored: stored)
                    .tag(stored.id)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 300)
            .overlay {
                if filtered.isEmpty {
                    emptyListPlaceholder
                }
            }
        } detail: {
            if let id = selectedID,
               let stored = controller.notes.first(where: { $0.id == id }) {
                NoteDetailView(stored: stored)
            } else {
                ContentUnavailableView(
                    "Выберите заметку",
                    systemImage: "waveform",
                    description: Text("⌥⇧Space — записать новую из любого приложения")
                )
            }
        }
        .searchable(text: $query, prompt: "Поиск по заметкам")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    controller.toggleRecording()
                } label: {
                    Label(
                        controller.isRecording ? "Стоп" : "Записать",
                        systemImage: controller.isRecording ? "stop.circle.fill" : "record.circle"
                    )
                }
                .tint(controller.isRecording ? .red : nil)
                .help(controller.isRecording ? "Остановить запись" : "Начать запись (⌥⇧Space)")
            }
        }
        .alert("Glassnote", isPresented: errorPresented) {
            Button("OK") { controller.lastError = nil }
        } message: {
            Text(controller.lastError ?? "")
        }
        .overlay(alignment: .bottom) {
            ModelStatusBar()
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { controller.lastError != nil },
            set: { if !$0 { controller.lastError = nil } }
        )
    }

    private var emptyListPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: query.isEmpty ? "mic.badge.plus" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(query.isEmpty ? "Пока нет заметок" : "Ничего не найдено")
                .foregroundStyle(.secondary)
        }
    }
}

struct NoteRow: View {
    var stored: StoredNote

    private var isPending: Bool {
        stored.note.segments.isEmpty && stored.transcript.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(stored.note.title)
                    .font(.headline)
                    .lineLimit(1)
                if isPending {
                    ProgressView().controlSize(.small)
                }
            }
            HStack(spacing: 6) {
                Text(stored.note.createdAt, format: .dateTime.day().month().hour().minute())
                Text("·")
                Text(Format.mmss(stored.note.durationSec))
                if let lang = stored.note.language, !lang.isEmpty {
                    Text("·")
                    Text(lang.uppercased())
                }
                if stored.note.edited {
                    Image(systemName: "pencil")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

/// Статус загрузки модели внизу окна — виден только пока модель не готова.
struct ModelStatusBar: View {
    @ObservedObject private var transcriber = AppController.shared.transcriber

    var body: some View {
        switch transcriber.modelState {
        case .loading(let name):
            capsule {
                ProgressView().controlSize(.small)
                Text("Загрузка модели \(name)… (~1.6 ГБ, только при первом запуске)")
            }
        case .failed(let message):
            capsule {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
            }
        case .notLoaded, .ready:
            EmptyView()
        }
    }

    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8, content: content)
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 12)
    }
}
