import Foundation

// Turns cumulative nettop counters into per-poll deltas.
// Keyed by (pid, name) so pid reuse starts a fresh baseline.
actor NetworkPoller {
    private struct Key: Hashable { let pid: Int; let name: String }
    private var baselines: [Key: (inB: Int, outB: Int)] = [:]

    func computeDeltas(_ samples: [ProcessSample]) -> [RawDelta] {
        // One empty read (nettop hiccup) must not wipe every baseline —
        // that would silently lose all traffic across two poll intervals.
        guard !samples.isEmpty else { return [] }
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

            d = await p.computeDeltas([])
            assert(d.isEmpty, "empty read emits nothing")
            d = await p.computeDeltas([ProcessSample(name: "b", pid: 1, bytesIn: 600, bytesOut: 10)])
            assert(d.first?.bytesInDelta == 100 && d.first?.bytesOutDelta == 5,
                   "empty read keeps baselines — delta resumes, not re-baselined")

            let ps = NettopParser.parse(",bytes_in,bytes_out,\ncom.apple.WebKit.Networking.881,1000,200,\n")
            assert(ps.count == 1 && ps[0].pid == 881 && ps[0].name == "com.apple.WebKit.Networking"
                   && ps[0].bytesIn == 1000 && ps[0].bytesOut == 200, "last-dot pid split")

            // DB recovery: a corrupt file must be set aside (not deleted) and
            // replaced with a working fresh database — no crash, no data loss.
            let fm = FileManager.default
            let tempPath = NSTemporaryDirectory() + "sysline-selftest-\(getpid()).sqlite"
            fm.createFile(atPath: tempPath, contents: Data("not a database".utf8))
            let database = Database.openWithRecovery(path: tempPath)
            try? await database.run(
                "INSERT INTO speed_tests (ts,down_bps,up_bps,ping_ms,jitter_ms,network) VALUES (1,1,1,1,1,'t')")
            let rows = (try? await database.query("SELECT COUNT(*) FROM speed_tests")) ?? []
            assert(rows.first?.first?.intValue == 1, "recovered database is usable")
            let setAside = ((try? fm.contentsOfDirectory(atPath: NSTemporaryDirectory())) ?? [])
                .filter { $0.hasPrefix("sysline-selftest-\(getpid())") && $0.contains(".corrupt-") }
            assert(!setAside.isEmpty, "corrupt file was set aside, not deleted")
            for leftover in setAside { try? fm.removeItem(atPath: NSTemporaryDirectory() + leftover) }
            for suffix in ["", "-wal", "-shm"] { try? fm.removeItem(atPath: tempPath + suffix) }

            print("selftest: PASS")
            exit(0)
        }
    }
}
#endif
