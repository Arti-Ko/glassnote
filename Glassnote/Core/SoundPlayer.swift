import AppKit

/// Системные звуки старта и окончания записи.
enum SoundPlayer {
    static func playStart() { NSSound(named: "Tink")?.play() }
    static func playStop() { NSSound(named: "Glass")?.play() }
}
