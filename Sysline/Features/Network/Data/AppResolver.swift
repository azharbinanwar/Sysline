import AppKit

struct ResolvedApp: Sendable {
    let bundleID: String
    let name: String
}

// Maps a pid to the app that owns it. Helpers (renderers, GPU, etc.) have no
// bundle of their own, so we walk up the parent chain to the real app.
enum AppResolver {
    static func resolve(pid: Int) -> ResolvedApp? {
        var current = Int32(pid)
        for _ in 0..<8 {
            guard current > 1 else { break }
            if let app = NSRunningApplication(processIdentifier: current),
               let bundleID = app.bundleIdentifier {
                let name = app.localizedName
                    ?? app.bundleURL?.deletingPathExtension().lastPathComponent
                    ?? bundleID
                return ResolvedApp(bundleID: bundleID, name: name)
            }
            guard let parent = parentPID(current) else { break }
            current = parent
        }
        return nil
    }

    private static func parentPID(_ pid: Int32) -> Int32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = mib.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, 4, &info, &size, nil, 0)
        }
        guard result == 0, size > 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 0 ? ppid : nil
    }
}
