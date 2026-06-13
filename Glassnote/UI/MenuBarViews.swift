import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject private var controller = AppController.shared

    var body: some View {
        switch controller.phase {
        case .idle:
            Image(nsImage: Self.dot(.secondaryLabelColor, filled: false))
        case .recording:
            Image(nsImage: Self.dot(.systemGreen, filled: true))
        case .transcribing:
            Image(nsImage: Self.dot(.systemBlue, filled: true))
        }
    }

    /// Маленький круглый индикатор для menu bar: серое кольцо в покое,
    /// залитый цветной кружок при записи (зелёный) и расшифровке (синий).
    static func dot(_ color: NSColor, filled: Bool) -> NSImage {
        let symbol = filled ? "circle.fill" : "circle"
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Glassnote")?
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
