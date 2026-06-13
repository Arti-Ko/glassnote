import SwiftUI
import KeyboardShortcuts

@main
struct GlassnoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var controller = AppController.shared

    var body: some Scene {
        WindowGroup("Glassnote", id: "library") {
            LibraryView()
                .environmentObject(controller)
        }
        .defaultSize(width: 920, height: 600)

        Settings {
            SettingsView()
                .environmentObject(controller)
        }

        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(controller)
        } label: {
            MenuBarLabel()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) {
            Task { @MainActor in AppController.shared.toggleRecording() }
        }
    }

    /// Приложение живёт в menu bar: закрытие окна не прерывает запись и расшифровку.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Не даём процессу умереть посреди записи или расшифровки —
    /// иначе аудио останется без note.json/transcript.md.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let controller = AppController.shared
        let wasRecording = controller.isRecording
        if wasRecording {
            controller.toggleRecording() // останавливает запись и ставит сохранение в очередь
        }
        guard wasRecording || controller.transcribingCount > 0 else { return .terminateNow }

        Task { @MainActor in
            let deadline = Date().addingTimeInterval(600)
            while (AppController.shared.transcribingCount > 0 || AppController.shared.isRecording),
                  Date() < deadline {
                try? await Task.sleep(for: .milliseconds(200))
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
