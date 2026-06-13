import AppKit
import SwiftUI

/// Плавающая неактивирующая стеклянная панель записи.
/// Не перехватывает фокус у активного приложения.
@MainActor
final class RecordingPanelController {
    private var panel: NSPanel?

    func show(controller: AppController) {
        if panel == nil {
            panel = makePanel(controller: controller)
        }
        guard let panel else { return }
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(controller: AppController) -> NSPanel {
        let view = RecordingPanelView(recorder: controller.recorder)
            .environmentObject(controller)
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .fullSizeContentView, .nonactivatingPanel]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        // До первого layout у hosting-вью нулевой размер — центрирование ломается.
        panel.setContentSize(hosting.view.fittingSize)
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 120)
        panel.setFrameOrigin(origin)
    }
}
