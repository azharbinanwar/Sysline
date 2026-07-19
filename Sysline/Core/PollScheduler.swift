import Foundation

extension Notification.Name {
    static let syslineDataChanged = Notification.Name("syslineDataChanged")
}

// Drives the poll loop: nettop → deltas → store, plus an hourly rollup.
@MainActor
final class PollScheduler {
    static let shared = PollScheduler()

    private let runner = NettopRunner()
    private let poller = NetworkPoller()
    private let store = NetworkStore(db: .shared)
    private var task: Task<Void, Never>?
    private var lastMaintenance = Date.distantPast

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            await self.store.runMaintenance()
            while !Task.isCancelled {
                await self.tick()
                try? await Task.sleep(for: .seconds(Prefs.pollInterval))
            }
        }
    }

    private func tick() async {
        guard let output = await runner.run() else { return }
        let samples = NettopParser.parse(output)
        let raw = await poller.computeDeltas(samples)   // always update baselines
        guard !Prefs.paused, !raw.isEmpty else { return } // paused → discard, baselines stay fresh

        let network = CurrentNetwork.identifier()
        let ts = Int(Date().timeIntervalSince1970)
        let deltas = raw.map { r -> SampleDelta in
            let app = AppResolver.resolve(pid: r.pid)
            return SampleDelta(ts: ts,
                               bundleID: app?.bundleID ?? AppIcon.otherBundleID,
                               appName: app?.name ?? "Other processes",
                               pid: r.pid, network: network,
                               bytesInDelta: r.bytesInDelta, bytesOutDelta: r.bytesOutDelta)
        }
        await store.insert(deltas)

        if Date().timeIntervalSince(lastMaintenance) > 3600 {
            lastMaintenance = Date()
            await store.runMaintenance()
        }
        NotificationCenter.default.post(name: .syslineDataChanged, object: nil)
        await AlertEngine.shared.evaluate()
    }
}
