import Foundation
import Combine
import AppKit

struct AppUpdate: Equatable {
    let version: String
    let pageURL: URL
    let zipURL: URL?
}

enum UpdateStatus: Equatable {
    case idle, checking, upToDate, downloading, installing
    case error(String)
}

/// Проверка/скачивание/установка обновлений через GitHub Releases.
/// Установка: скачивает zip, распаковывает, заменяет .app и перезапускается.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var available: AppUpdate?
    @Published var status: UpdateStatus = .idle

    private let repo = "Arti-Ko/glassnote"
    var currentVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0" }

    func check(manual: Bool = false) {
        if manual { status = .checking }
        Task {
            guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let rawTag = json["tag_name"] as? String,
                      let page = json["html_url"] as? String,
                      let pageURL = URL(string: page)
                else { if manual { status = .error("Некорректный ответ GitHub") }; return }

                let tag = rawTag.hasPrefix("v") ? String(rawTag.dropFirst()) : rawTag
                var zip: URL?
                if let assets = json["assets"] as? [[String: Any]] {
                    for a in assets {
                        if let name = a["name"] as? String, name.hasSuffix(".zip"),
                           let u = a["browser_download_url"] as? String { zip = URL(string: u); break }
                    }
                }
                if Self.isNewer(tag, than: currentVersion) {
                    available = AppUpdate(version: tag, pageURL: pageURL, zipURL: zip)
                    status = .idle
                } else if manual {
                    status = .upToDate
                }
            } catch {
                if manual { status = .error(error.localizedDescription) }
            }
        }
    }

    func installUpdate() {
        guard let zip = available?.zipURL else {
            if let p = available?.pageURL { NSWorkspace.shared.open(p) }
            return
        }
        status = .downloading
        Task {
            do {
                let (tmp, _) = try await URLSession.shared.download(from: zip)
                status = .installing
                let fm = FileManager.default
                let work = fm.temporaryDirectory.appendingPathComponent("glassnote-update", isDirectory: true)
                try? fm.removeItem(at: work)
                try fm.createDirectory(at: work, withIntermediateDirectories: true)
                try runProcess("/usr/bin/ditto", ["-x", "-k", tmp.path, work.path])

                let apps = (try? fm.contentsOfDirectory(at: work, includingPropertiesForKeys: nil))?
                    .filter { $0.pathExtension == "app" } ?? []
                guard let newApp = apps.first else { status = .error("В архиве нет .app"); return }

                let dest = Bundle.main.bundlePath
                let script = """
                #!/bin/bash
                sleep 1
                rm -rf "\(dest)"
                /usr/bin/ditto "\(newApp.path)" "\(dest)"
                xattr -dr com.apple.quarantine "\(dest)" 2>/dev/null
                open "\(dest)"
                """
                let scriptURL = fm.temporaryDirectory.appendingPathComponent("gn_update.sh")
                try script.write(to: scriptURL, atomically: true, encoding: .utf8)

                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/bash")
                p.arguments = [scriptURL.path]
                try p.run()
                NSApp.terminate(nil)
            } catch {
                status = .error(error.localizedDescription)
            }
        }
    }

    private func runProcess(_ exe: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
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
