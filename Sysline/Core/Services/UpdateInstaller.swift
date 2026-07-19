import AppKit
import Foundation

enum UpdateInstallError: LocalizedError {
    case mountFailed, appNotFoundInDMG, stagingFailed, swapFailed(String)
    var errorDescription: String? {
        switch self {
        case .mountFailed: "The update image couldn't be mounted."
        case .appNotFoundInDMG: "The update image doesn't contain an app."
        case .stagingFailed: "The update couldn't be copied out of the image."
        case .swapFailed(let r): "The app couldn't be replaced: \(r)"
        }
    }
}

// Silent mount → stage → strip quarantine → atomic swap (with rollback) → relaunch.
enum UpdateInstaller {
    static func install(dmg: URL) async throws -> URL {
        let fm = FileManager.default
        let mount = fm.temporaryDirectory.appendingPathComponent("sysline-update-\(UUID().uuidString.prefix(8))", isDirectory: true)
        guard await run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-noautoopen", "-mountpoint", mount.path) == 0 else {
            throw UpdateInstallError.mountFailed
        }
        do {
            let installed = try installFromVolume(mount)
            await detach(mount)
            return installed
        } catch {
            await detach(mount)
            throw error
        }
    }

    static func relaunch(_ appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"\(appURL.path)\""
        let watcher = Process()
        watcher.executableURL = URL(fileURLWithPath: "/bin/sh")
        watcher.arguments = ["-c", script]
        try? watcher.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
    }

    private static func installFromVolume(_ volume: URL) throws -> URL {
        let fm = FileManager.default
        guard let source = try fm.contentsOfDirectory(at: volume, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else { throw UpdateInstallError.appNotFoundInDMG }

        let dest = Bundle.main.bundleURL                 // replace the running install in place
        let dir = dest.deletingLastPathComponent()
        let staging = dir.appendingPathComponent(".sysline-update-staging.app")
        let backup = dir.appendingPathComponent(".sysline-update-backup.app")

        try? fm.removeItem(at: staging)
        do { try fm.copyItem(at: source, to: staging) } catch { throw UpdateInstallError.stagingFailed }

        // Strip quarantine so Gatekeeper doesn't block the relaunch.
        _ = process("/usr/bin/xattr", "-dr", "com.apple.quarantine", staging.path)

        try? fm.removeItem(at: backup)
        do {
            if fm.fileExists(atPath: dest.path) { try fm.moveItem(at: dest, to: backup) }
            try fm.moveItem(at: staging, to: dest)       // same-volume atomic rename
        } catch {
            if fm.fileExists(atPath: backup.path), !fm.fileExists(atPath: dest.path) {
                try? fm.moveItem(at: backup, to: dest)   // rollback
            }
            throw UpdateInstallError.swapFailed(error.localizedDescription)
        }
        try? fm.removeItem(at: backup)
        return dest
    }

    private static func detach(_ mount: URL) async {
        _ = await run("/usr/bin/hdiutil", "detach", mount.path, "-quiet")
    }

    @discardableResult
    private static func process(_ launch: String, _ args: String...) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    @discardableResult
    private static func run(_ launch: String, _ args: String...) async -> Int32 {
        await withCheckedContinuation { cont in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: launch)
            p.arguments = args
            p.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
            do { try p.run() } catch { cont.resume(returning: -1) }
        }
    }
}
