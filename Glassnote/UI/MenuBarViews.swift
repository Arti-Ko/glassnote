import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject private var controller = AppController.shared

    var body: some View {
        switch controller.phase {
        case .idle:
            Image(systemName: "waveform.circle")
        case .recording:
            Image(nsImage: Self.tinted("record.circle.fill", .systemGreen))
        case .transcribing:
            Image(nsImage: Self.tinted("waveform.circle.fill", .systemBlue))
        }
    }

    /// Цветная (не template) иконка — menu bar сохраняет её цвет.
    static func tinted(_ symbolName: String, _ color: NSColor) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }
}

struct MenuBarMenu: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(controller.isRecording ? "Остановить запись" : "Новая заметка") {
            controller.toggleRecording()
        }
        if controller.transcribingCount > 0 {
            Text("Расшифровывается: \(controller.transcribingCount)…")
        }
        Divider()
        Button("Открыть Glassnote") {
            openWindow(id: "library")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink {
            Text("Настройки…")
        }
        Divider()
        Button("Выйти из Glassnote") {
            NSApp.terminate(nil)
        }
    }
}
