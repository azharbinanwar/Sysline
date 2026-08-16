import Foundation

// Runs one nettop sample and returns its raw stdout. Never throws — a failed
// sample just yields nil and the poll loop skips it.
struct NettopRunner: Sendable {
    func run() async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
            // -t external (all non-loopback interfaces) + -t undefined (sockets
            // not yet tied to an interface): counts every real connection type
            // while excluding localhost traffic, e.g. Android Studio ↔ emulator
            // streaming that once recorded 270 GB/day of phantom usage.
            process.arguments = ["-P", "-L", "1", "-x",
                                 "-t", "external", "-t", "undefined",
                                 "-J", "bytes_in,bytes_out"]
            let pipe = Pipe()
            process.standardOutput = pipe
            // Discard stderr: an unread stderr pipe that fills up would block
            // nettop forever, and this loop with it.
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                return nil
            }
            // Watchdog: a wedged nettop must not halt recording until relaunch.
            let watchdog = Task.detached {
                try? await Task.sleep(for: .seconds(10))
                if process.isRunning { process.terminate() }
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            watchdog.cancel()
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                return nil   // killed or failed → partial output, skip this poll
            }
            return String(data: data, encoding: .utf8)
        }.value
    }
}
