import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

struct RecordingPanelView: View {
    @ObservedObject var recorder: AudioRecorder
    @EnvironmentObject private var controller: AppController

    var body: some View {
        HStack(spacing: 14) {
            PulsingDot()

            WaveformView(levels: recorder.levelHistory)
                .frame(width: 150, height: 36)

            Text(Format.mmss(recorder.elapsed))
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 56, alignment: .trailing)

            Button {
                controller.minimizePanel()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Свернуть — запись продолжится (индикатор в menu bar)")

            Button {
                controller.toggleRecording()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Остановить запись")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(VisualEffectView(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(8)
    }
}

struct WaveformView: View {
    var levels: [Float]

    var body: some View {
        GeometryReader { geo in
            // Ширина полоски считается под контейнер — иначе фиксированные
            // полоски переполняют рамку и налезают на таймер справа.
            let count = max(levels.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(.primary.opacity(0.8))
                        .frame(width: barWidth, height: max(3, CGFloat(level) * geo.size.height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }
}

struct PulsingDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 10, height: 10)
            .scaleEffect(pulse ? 1.25 : 0.9)
            .opacity(pulse ? 1 : 0.7)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
