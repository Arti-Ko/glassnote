import Foundation

enum Format {
    /// 94.2 → "1:34"
    static func mmss(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
