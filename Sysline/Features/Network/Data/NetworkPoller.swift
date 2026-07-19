import Foundation

// Turns cumulative nettop counters into per-poll deltas.
// Keyed by (pid, name) so pid reuse starts a fresh baseline.
actor NetworkPoller {
    private struct Key: Hashable { let pid: Int; let name: String }
    private var baselines: [Key: (inB: Int, outB: Int)] = [:]

    func computeDeltas(_ samples: [ProcessSample]) -> [RawDelta] {
        var deltas: [RawDelta] = []
        var seen = Set<Key>()

        for s in samples {
            let key = Key(pid: s.pid, name: s.name)
            seen.insert(key)

            let dIn: Int, dOut: Int
            if let base = baselines[key] {
                let ri = s.bytesIn - base.inB
                let ro = s.bytesOut - base.outB
                // On a decrease (counter reset / pid churn / jitter) re-baseline and
                // count 0. Adding the full current value here caused large over-counts.
                dIn  = ri < 0 ? 0 : ri
                dOut = ro < 0 ? 0 : ro
            } else {
                dIn = 0; dOut = 0                  // first sighting → baseline only
            }
            baselines[key] = (s.bytesIn, s.bytesOut)

            if dIn > 0 || dOut > 0 {
                deltas.append(RawDelta(name: s.name, pid: s.pid,
                                       bytesInDelta: dIn, bytesOutDelta: dOut))
            }
        }

        baselines = baselines.filter { seen.contains($0.key) } // drop gone pids
        return deltas
    }
}

#if DEBUG
extension NetworkPoller {
    // Run with:  Sysline --selftest
    static func runSelfTestIfRequested() {
        guard CommandLine.arguments.contains("--selftest") else { return }
        Task {
            let p = NetworkPoller()
            func s(_ i: Int, _ o: Int) -> [ProcessSample] {
                [ProcessSample(name: "a", pid: 1, bytesIn: i, bytesOut: o)]
            }
            var d = await p.computeDeltas(s(100, 10))
            assert(d.isEmpty, "first sighting emits nothing")

            d = await p.computeDeltas(s(150, 15))
            assert(d.first?.bytesInDelta == 50 && d.first?.bytesOutDelta == 5, "normal delta")

            d = await p.computeDeltas(s(20, 2))
            assert(d.isEmpty, "counter reset → 0, re-baseline (no spike)")

            d = await p.computeDeltas(s(30, 5))
            assert(d.first?.bytesInDelta == 10 && d.first?.bytesOutDelta == 3, "delta resumes from new baseline")

            d = await p.computeDeltas([ProcessSample(name: "b", pid: 1, bytesIn: 500, bytesOut: 5)])
            assert(d.isEmpty, "pid reuse with new name is a fresh baseline")

            let ps = NettopParser.parse(",bytes_in,bytes_out,\ncom.apple.WebKit.Networking.881,1000,200,\n")
            assert(ps.count == 1 && ps[0].pid == 881 && ps[0].name == "com.apple.WebKit.Networking"
                   && ps[0].bytesIn == 1000 && ps[0].bytesOut == 200, "last-dot pid split")

            print("selftest: PASS")
            exit(0)
        }
    }
}
#endif
