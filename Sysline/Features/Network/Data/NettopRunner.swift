import Foundation

// Runs one nettop sample and returns its raw stdout. Never throws — a failed
// sample just yields nil and the poll loop skips it.
struct NettopRunner: Sendable {
    func run() async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
            process.arguments = ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        }.value
    }
}
