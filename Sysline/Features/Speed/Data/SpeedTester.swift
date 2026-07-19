import Foundation
import Combine

// Thread-safe byte tally. The URLSession delegate fires thousands of times a
// second across all streams; it bumps this directly (no main-thread hop) and
// the UI samples it on a timer.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var v = 0
    func add(_ n: Int) { lock.lock(); v += n; lock.unlock() }
    func reset() { lock.lock(); v = 0; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return v }
}

// Real-time speed test against Cloudflare. Runs several parallel streams for a
// fixed time window (one connection can't fill a high-latency link) and relaunches
// any that finish mid-window so the pipe stays saturated.
@MainActor
final class SpeedTester: NSObject, ObservableObject {
    enum Phase: Equatable { case idle, ping, download, upload, done }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var mbps = 0.0          // live throughput of the current phase
    @Published private(set) var downMbps = 0.0
    @Published private(set) var upMbps = 0.0
    @Published private(set) var idlePing = 0
    @Published private(set) var jitter = 0
    @Published private(set) var downLatency = 0
    @Published private(set) var upLatency = 0
    @Published private(set) var note: String?       // surfaced error, e.g. a failed download

    // tuning
    private let streams = 5            // parallel connections per phase (gentle on hotspots)
    private let warmup = 1.0           // seconds discarded so we measure steady state
    private let window = 4.0           // measured seconds per phase

    private let downURL = URL(string: "https://speed.cloudflare.com/__down?bytes=52428800")! // 50 MB each (Cloudflare caps at 100 MB)
    private let pingURL = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
    private let upURL = URL(string: "https://speed.cloudflare.com/__up")!
    private let upBody = Data(count: 15_000_000) // small shared buffer; streams relaunch as they drain

    private let counter = Counter()
    private var session: URLSession!
    private var phaseStart = Date()
    private var probing = false
    private var streaming = false
    private var makeTask: (() -> URLSessionTask)?
    private var tasks: [URLSessionTask] = []
    private var lastError: String?

    func run() async {
        // clear the previous result so a retry starts blank, not stale
        downMbps = 0; upMbps = 0; idlePing = 0; jitter = 0; downLatency = 0; upLatency = 0; mbps = 0
        note = nil; lastError = nil

        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

        phase = .ping
        let ping = await idleLatency()
        idlePing = ping.median; jitter = ping.jitter

        phase = .download
        probing = true
        let dLat = Task { await loadedLatency() }
        let makeDown = { self.session.dataTask(with: self.downURL) }
        await stream(makeDown)
        if finalMbps() < 0.5 { lastError = nil; await stream(makeDown) }   // one retry if it came back empty
        probing = false
        downMbps = finalMbps(); downLatency = await dLat.value
        if downMbps < 0.5 { note = lastError ?? "Download failed — server unreachable" }

        mbps = 0                                             // sweep the dial back to zero…
        try? await Task.sleep(for: .milliseconds(450))       // …before the upload run climbs

        phase = .upload
        probing = true
        let uLat = Task { await loadedLatency() }
        await stream {
            var req = URLRequest(url: self.upURL); req.httpMethod = "POST"
            return self.session.uploadTask(with: req, from: self.upBody)
        }
        probing = false
        upMbps = finalMbps(); upLatency = await uLat.value

        mbps = 0                                             // return the dial to zero
        phase = .done
        session.invalidateAndCancel()

        let ip = await IPInfo.fetch()
        let network = CurrentNetwork.identifier()                 // SSID when Location is granted, else "Unknown network"
        await SpeedStore(db: .shared).insert(downMbps: downMbps, upMbps: upMbps,
                                             ping: idlePing, jitter: jitter,
                                             network: network, isp: ip?.isp ?? "", place: ip?.place ?? "")
    }

    // Fires N parallel tasks, warms up, then measures a fixed window and cancels.
    // A 10 Hz ticker samples the byte counter so the UI stays smooth.
    private func stream(_ make: @escaping () -> URLSessionTask) async {
        counter.reset(); mbps = 0; phaseStart = Date()
        makeTask = make; streaming = true
        tasks = (0..<streams).map { _ in make() }
        tasks.forEach { $0.resume() }

        let ticker = Task { @MainActor in
            while streaming {
                try? await Task.sleep(for: .milliseconds(100))
                mbps = finalMbps()
            }
        }

        try? await Task.sleep(for: .seconds(warmup))
        counter.reset(); phaseStart = Date()            // discard ramp-up
        try? await Task.sleep(for: .seconds(window))

        streaming = false; makeTask = nil
        ticker.cancel()
        tasks.forEach { $0.cancel() }
        tasks = []
    }

    private func finalMbps() -> Double {
        let e = Date().timeIntervalSince(phaseStart)
        return e > 0.05 ? Double(counter.value) * 8 / e / 1_000_000 : mbps
    }

    // Small pings on a plain session so they don't feed the delegate byte counter.
    private func idleLatency() async -> (median: Int, jitter: Int) {
        var lat: [Double] = []
        for _ in 0..<3 {
            let s = Date()
            _ = try? await URLSession.shared.data(from: pingURL)
            lat.append(Date().timeIntervalSince(s) * 1000)
        }
        guard !lat.isEmpty else { return (0, 0) }
        let sorted = lat.sorted()
        let mean = lat.reduce(0, +) / Double(lat.count)
        return (Int(sorted[sorted.count / 2]),
                Int(lat.map { abs($0 - mean) }.reduce(0, +) / Double(lat.count)))
    }

    private func loadedLatency() async -> Int {
        var lat: [Double] = []
        while probing {
            let s = Date()
            _ = try? await URLSession.shared.data(from: pingURL)
            lat.append(Date().timeIntervalSince(s) * 1000)
            try? await Task.sleep(for: .milliseconds(280))
        }
        guard !lat.isEmpty else { return idlePing }
        return Int(lat.sorted()[lat.count / 2])
    }
}

extension SpeedTester: URLSessionDataDelegate {
    nonisolated func urlSession(_ s: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        counter.add(data.count)
    }
    nonisolated func urlSession(_ s: URLSession, task: URLSessionTask,
                                didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                                totalBytesExpectedToSend: Int64) {
        counter.add(Int(bytesSent))
    }
    // A stream that fully drained its 200 transfer is replaced so throughput holds.
    // We relaunch ONLY on a real 200 finish — a 403/429 (rate limit) completes
    // "successfully" too, and relaunching on that would spin a tight loop.
    nonisolated func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let cancelled = (error as? URLError)?.code == .cancelled
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        let ok = error == nil && status == 200
        let message: String? = cancelled ? nil
            : error?.localizedDescription ?? (status != 200 ? "Server busy (HTTP \(status))" : nil)
        Task { @MainActor in
            if let message { self.lastError = message }
            guard self.streaming, ok, let make = self.makeTask else { return }
            let t = make(); self.tasks.append(t); t.resume()
        }
    }
}
