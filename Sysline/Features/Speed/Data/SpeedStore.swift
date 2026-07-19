import Foundation

struct SpeedStore {
    let db: Database

    func insert(downMbps: Double, upMbps: Double, ping: Int, jitter: Int,
                network: String, isp: String, place: String) async {
        try? await db.run(
            "INSERT INTO speed_tests (ts, down_bps, up_bps, ping_ms, jitter_ms, network, isp, place) VALUES (?,?,?,?,?,?,?,?)",
            [.int(Int64(Date().timeIntervalSince1970)),
             .int(Int64(downMbps * 1_000_000)), .int(Int64(upMbps * 1_000_000)),
             .int(Int64(ping)), .int(Int64(jitter)), .text(network), .text(isp), .text(place)]
        )
    }

    func history(limit: Int = 50) async -> [SpeedResult] {
        let rows = (try? await db.query(
            "SELECT id, ts, down_bps, up_bps, ping_ms, jitter_ms, network, isp, place FROM speed_tests ORDER BY ts DESC LIMIT ?",
            [.int(Int64(limit))])) ?? []
        return rows.compactMap { r in
            guard r.count >= 9 else { return nil }
            return SpeedResult(id: Int64(r[0].intValue),
                               date: Date(timeIntervalSince1970: TimeInterval(r[1].intValue)),
                               downMbps: Double(r[2].intValue) / 1_000_000,
                               upMbps: Double(r[3].intValue) / 1_000_000,
                               pingMs: r[4].intValue, jitterMs: r[5].intValue,
                               network: r[6].textValue, isp: r[7].textValue, place: r[8].textValue)
        }
    }
}
