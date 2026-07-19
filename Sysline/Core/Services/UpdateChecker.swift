import Foundation
import Combine
import CryptoKit

// Checks GitHub Releases for a newer Sysline, downloads the DMG, verifies its
// SHA-256, then hands off to UpdateInstaller for a silent swap + relaunch.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let repo = "azharbinanwar/Sysline"

    enum Phase: Equatable {
        case idle, checking, upToDate
        case available(String)
        case downloading(Double)
        case installing
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastChecked: Date?

    private init() {
        lastChecked = UserDefaults.standard.object(forKey: "updates.lastChecked") as? Date
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    func checkIfDue() async {
        if let last = lastChecked, Date().timeIntervalSince(last) < 86_400 { return }
        await check()
    }

    func check() async {
        guard phase != .checking else { return }
        phase = .checking
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            struct Release: Decodable { let tag_name: String }
            let tag = try JSONDecoder().decode(Release.self, from: data).tag_name
            let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            lastChecked = Date()
            UserDefaults.standard.set(lastChecked, forKey: "updates.lastChecked")
            phase = isNewer(remote, than: currentVersion) ? .available(remote) : .upToDate
        } catch {
            phase = .failed("Couldn't reach GitHub — check your connection.")
        }
    }

    func downloadAndInstall() async {
        guard case .available(let version) = phase else { return }
        phase = .downloading(0)
        do {
            let base = "https://github.com/\(Self.repo)/releases/download/v\(version)"
            let expected = try await fetchChecksum(URL(string: "\(base)/Sysline.dmg.sha256")!)

            let dmgURL = FileManager.default.temporaryDirectory.appendingPathComponent("Sysline-\(version).dmg")
            try? FileManager.default.removeItem(at: dmgURL)

            let (bytes, resp) = try await URLSession.shared.bytes(from: URL(string: "\(base)/Sysline.dmg")!)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let total = resp.expectedContentLength

            FileManager.default.createFile(atPath: dmgURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: dmgURL)
            defer { try? handle.close() }

            var hasher = SHA256()
            var received: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(131_072)
            for try await byte in bytes {
                buffer.append(byte); received += 1
                if buffer.count >= 131_072 {
                    hasher.update(data: buffer)
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    if total > 0 { phase = .downloading(Double(received) / Double(total)) }
                }
            }
            if !buffer.isEmpty { hasher.update(data: buffer); try handle.write(contentsOf: buffer) }
            try? handle.close()

            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == expected else {
                phase = .failed("Checksum mismatch — download may be corrupted.")
                return
            }

            phase = .installing
            let installed = try await UpdateInstaller.install(dmg: dmgURL)
            UpdateInstaller.relaunch(installed)
        } catch {
            phase = .failed("Update failed: \(error.localizedDescription)")
        }
    }

    private func fetchChecksum(_ url: URL) async throws -> String {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).first?.lowercased() ?? ""
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").map { Int($0) ?? 0 }
        let l = local.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }
}
