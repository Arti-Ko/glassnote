import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject private var controller: AppController
    @ObservedObject private var transcriber = AppController.shared.transcriber
    @AppStorage(AppConfig.languageKey) private var languageRaw = RecordingLanguage.auto.rawValue
    @ObservedObject private var updater = UpdateChecker.shared

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
            Section("Обновления") {
                LabeledContent("Версия:") {
                    Text(updater.currentVersion).foregroundStyle(.secondary)
                }
                updateRow
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { updater.check() }
    }

    @ViewBuilder private var updateRow: some View {
        switch updater.status {
        case .checking:
            HStack { ProgressView().controlSize(.small); Text("Проверка…").foregroundStyle(.secondary) }
        case .downloading:
            HStack { ProgressView().controlSize(.small); Text("Загрузка обновления…").foregroundStyle(.secondary) }
        case .installing:
            HStack { ProgressView().controlSize(.small); Text("Установка и перезапуск…").foregroundStyle(.secondary) }
        default:
            if let u = updater.available {
                Button("Установить \(u.version) и перезапустить") { updater.installUpdate() }
            } else {
                HStack {
                    Button("Проверить обновления") { updater.check(manual: true) }
                    if case .upToDate = updater.status { Text("Актуальная версия").foregroundStyle(.secondary) }
                    if case .error(let m) = updater.status { Text(m).foregroundStyle(.red).font(.caption) }
                }
            }
        }
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
