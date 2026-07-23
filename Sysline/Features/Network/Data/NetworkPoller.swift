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

            var base = baselines[key] ?? (inB: s.bytesIn, outB: s.bytesOut)
            let dIn: Int
            if s.bytesIn >= base.inB {
                dIn = s.bytesIn - base.inB
                base.inB = s.bytesIn
            } else if s.bytesIn > 0 {
                dIn = 0; base.inB = s.bytesIn   // counter reset → re-baseline
            } else {
                dIn = 0                         // jitter (0) → ignore, keep old baseline
            }

            let dOut: Int
            if s.bytesOut >= base.outB {
                dOut = s.bytesOut - base.outB
                base.outB = s.bytesOut
            } else if s.bytesOut > 0 {
                dOut = 0; base.outB = s.bytesOut
            } else {
                dOut = 0
            }
            baselines[key] = base

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

            d = await p.computeDeltas(s(0, 0))
            assert(d.isEmpty, "jitter to 0 -> ignore")

            d = await p.computeDeltas(s(160, 18))
            assert(d.first?.bytesInDelta == 10 && d.first?.bytesOutDelta == 3, "resumes from old baseline after jitter")

            d = await p.computeDeltas(s(20, 2))
            assert(d.isEmpty, "counter reset to positive value -> re-baseline (no spike)")

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
