import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject private var controller: AppController
    @ObservedObject private var transcriber = AppController.shared.transcriber
    @AppStorage(AppConfig.languageKey) private var languageRaw = RecordingLanguage.auto.rawValue

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Хоткей записи:", name: .toggleRecording)

            Picker("Язык записи:", selection: $languageRaw) {
                ForEach(RecordingLanguage.allCases) { lang in
                    Text(lang.label).tag(lang.rawValue)
                }
            }
            .help("Автоопределение или принудительный язык. Применяется к новым записям.")

            LabeledContent("Модель распознавания:") {
                Text(modelStatusText)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Папка заметок:") {
                HStack(spacing: 8) {
                    Text(notesPath)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Button("Открыть в Finder") {
                        if let root = controller.store?.rootURL {
                            NSWorkspace.shared.activateFileViewerSelecting([root])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var modelStatusText: String {
        switch transcriber.modelState {
        case .notLoaded: return "не загружена"
        case .loading(let name): return "загружается: \(name)…"
        case .ready(let name): return "\(name) (локально, офлайн)"
        case .failed(let message): return "ошибка: \(message)"
        }
    }

    private var notesPath: String {
        controller.store?.rootURL.path(percentEncoded: false) ?? "—"
    }
}
