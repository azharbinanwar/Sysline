import Foundation

// Writes deltas and keeps the DB small (hourly rollup + retention).
struct NetworkStore {
    let db: Database

    func insert(_ deltas: [SampleDelta]) async {
        guard !deltas.isEmpty else { return }
        let sql = "INSERT INTO network_samples (ts, bundle_id, app_name, pid, network, bytes_in_delta, bytes_out_delta) VALUES (?,?,?,?,?,?,?)"
        let statements: [(String, [SQLValue])] = deltas.map { d in
            (sql, [.int(Int64(d.ts)), .text(d.bundleID), .text(d.appName), .int(Int64(d.pid)),
                   .text(d.network), .int(Int64(d.bytesInDelta)), .int(Int64(d.bytesOutDelta))])
        }
        try? await db.writeBatch(statements)
    }

    // Idempotent: recomputes hourly rows from the raw samples still on hand,
    // then prunes. Safe to run repeatedly.
    func runMaintenance() async {
        let now = Int(Date().timeIntervalSince1970)
        try? await db.run("""
            INSERT OR REPLACE INTO network_hourly (hour_start, bundle_id, app_name, network, bytes_in, bytes_out)
            SELECT (ts/3600)*3600, bundle_id, MAX(app_name), network, SUM(bytes_in_delta), SUM(bytes_out_delta)
            FROM network_samples GROUP BY 1, bundle_id, network
            """)
        try? await db.run("DELETE FROM network_samples WHERE ts < ?",
                          [.int(Int64(now - Constants.Retention.rawSampleHours * 3600))])
        try? await db.run("DELETE FROM network_hourly WHERE hour_start < ?",
                          [.int(Int64(now - Prefs.retentionDays * 86400))])
    }

    func clearAll() async {
        try? await db.run("DELETE FROM network_samples")
        try? await db.run("DELETE FROM network_hourly")
    }
}
