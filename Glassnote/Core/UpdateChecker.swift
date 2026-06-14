import Foundation
import Combine

struct AppUpdate: Equatable {
    let version: String
    let pageURL: URL
}

/// Проверка обновлений через GitHub Releases (без ручной установки).
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    @Published var available: AppUpdate?

    private let repo = "Arti-Ko/glassnote"

    func check() {
        Task {
            guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawTag = json["tag_name"] as? String,
                  let page = json["html_url"] as? String,
                  let pageURL = URL(string: page)
            else { return }

            let tag = rawTag.hasPrefix("v") ? String(rawTag.dropFirst()) : rawTag
            let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
            if Self.isNewer(tag, than: current) {
                self.available = AppUpdate(version: tag, pageURL: pageURL)
            }
        }
    }

    static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").map { Int($0) ?? 0 }
        let c = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}
