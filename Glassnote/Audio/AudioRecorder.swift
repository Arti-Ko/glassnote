import AVFoundation
import Combine

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var levelHistory: [Float] = AudioRecorder.emptyHistory

    private static let historyLength = 48
    private static var emptyHistory: [Float] { Array(repeating: 0, count: historyLength) }

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?

    enum RecorderError: LocalizedError {
        case startFailed
        var errorDescription: String? { "Не удалось начать запись с микрофона" }
    }

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    func start(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        guard r.record() else { throw RecorderError.startFailed }
        recorder = r
        elapsed = 0
        levelHistory = Self.emptyHistory
        // .common — чтобы метр и таймер не замирали во время скролла/драга.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let r = recorder else { return nil }
        let duration = r.currentTime
        let url = r.url
        r.stop()
        recorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        return (url, duration)
    }

    private func tick() {
        guard let r = recorder else { return }
        r.updateMeters()
        elapsed = r.currentTime
        let db = r.averagePower(forChannel: 0) // -160…0 dB
        let normalized = max(0, min(1, (db + 50) / 50))
        var history = levelHistory
        history.removeFirst()
        history.append(normalized)
        levelHistory = history
    }
}
