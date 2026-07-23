import Foundation

// Reads. Today/Yesterday come from raw samples (accurate); 7/30 Days from the
// hourly rollup (misses at most the current in-progress hour — negligible).
struct NetworkQuery {
    let db: Database

    func usage(_ range: DateRange, network: String?) async -> [AppUsage] {
        let (start, end) = range.bounds()
        // Threshold: use raw samples for the last 24 hours to ensure max accuracy
        // and include data not yet rolled up. Everything older comes from hourly.
        let rawThreshold = Int(Date().timeIntervalSince1970) - 24 * 3600
        let mid = max(start, rawThreshold)

        var allRows: [[SQLValue]] = []

        // 1. History from hourly table
        if start < mid {
            var sql = "SELECT bundle_id, MAX(app_name), SUM(bytes_in), SUM(bytes_out) FROM network_hourly WHERE hour_start >= ? AND hour_start < ?"
            var params: [SQLValue] = [.int(Int64(start)), .int(Int64(mid))]
            if let network { sql += " AND network = ?"; params.append(.text(network)) }
            sql += " GROUP BY bundle_id"
            allRows.append(contentsOf: (try? await db.query(sql, params)) ?? [])
        }

        // 2. Recent from raw samples
        if mid < end {
            var sql = "SELECT bundle_id, MAX(app_name), SUM(bytes_in_delta), SUM(bytes_out_delta) FROM network_samples WHERE ts >= ? AND ts < ?"
            var params: [SQLValue] = [.int(Int64(mid)), .int(Int64(end))]
            if let network { sql += " AND network = ?"; params.append(.text(network)) }
            sql += " GROUP BY bundle_id"
            allRows.append(contentsOf: (try? await db.query(sql, params)) ?? [])
        }

        // 3. Aggregate
        var combined: [String: AppUsage] = [:]
        for r in allRows {
            guard r.count >= 4 else { continue }
            let bid = r[0].textValue
            let name = r[1].textValue
            let i = r[2].intValue
            let o = r[3].intValue
            if let existing = combined[bid] {
                combined[bid] = AppUsage(bundleID: bid, name: name, bytesIn: existing.bytesIn + i, bytesOut: existing.bytesOut + o)
            } else {
                combined[bid] = AppUsage(bundleID: bid, name: name, bytesIn: i, bytesOut: o)
            }
        }

        return combined.values.sorted { $0.total > $1.total }
    }

    func trend(_ range: DateRange, network: String?) async -> [UsagePoint] {
        let (start, end) = range.bounds()
        let rawThreshold = Int(Date().timeIntervalSince1970) - 24 * 3600
        let mid = max(start, rawThreshold)
        let bucket = range.usesRawSamples ? 3600 : 86400

        var allRows: [[SQLValue]] = []

        if start < mid {
            var sql = "SELECT (hour_start/\(bucket))*\(bucket) AS b, SUM(bytes_in), SUM(bytes_out) FROM network_hourly WHERE hour_start >= ? AND hour_start < ?"
            var params: [SQLValue] = [.int(Int64(start)), .int(Int64(mid))]
            if let network { sql += " AND network = ?"; params.append(.text(network)) }
            sql += " GROUP BY b"
            allRows.append(contentsOf: (try? await db.query(sql, params)) ?? [])
        }

        if mid < end {
            var sql = "SELECT (ts/\(bucket))*\(bucket) AS b, SUM(bytes_in_delta), SUM(bytes_out_delta) FROM network_samples WHERE ts >= ? AND ts < ?"
            var params: [SQLValue] = [.int(Int64(mid)), .int(Int64(end))]
            if let network { sql += " AND network = ?"; params.append(.text(network)) }
            sql += " GROUP BY b"
            allRows.append(contentsOf: (try? await db.query(sql, params)) ?? [])
        }

        var combined: [Int: (inB: Int, outB: Int)] = [:]
        for r in allRows {
            guard r.count >= 3 else { continue }
            let b = r[0].intValue
            let i = r[1].intValue
            let o = r[2].intValue
            let existing = combined[b] ?? (0, 0)
            combined[b] = (existing.inB + i, existing.outB + o)
        }

        return combined.keys.sorted().compactMap { b in
            let vals = combined[b]!
            return UsagePoint(date: Date(timeIntervalSince1970: TimeInterval(b)),
                              bytesIn: vals.inB, bytesOut: vals.outB)
        }
    }

    func networks() async -> [String] {
        let rows = (try? await db.query("SELECT DISTINCT network FROM network_samples ORDER BY network")) ?? []
        return rows.compactMap { $0.first?.textValue }.filter { !$0.isEmpty }
    }

    // Total bytes over an arbitrary window — used by reminders/budgets.
    func total(from start: Int, to end: Int, network: String?) async -> Int {
        let rawThreshold = Int(Date().timeIntervalSince1970) - 24 * 3600
        let mid = max(start, rawThreshold)

        var total = 0

        if start < mid {
            var sql = "SELECT SUM(bytes_in) + SUM(bytes_out) FROM network_hourly WHERE hour_start >= ? AND hour_start < ?"
            var params: [SQLValue] = [.int(Int64(start)), .int(Int64(mid))]
            if let network { sql += " AND network = ?"; params.append(.text(network)) }
            let rows = (try? await db.query(sql, params)) ?? []
            total += rows.first?.first?.intValue ?? 0
        }

        if mid < end {
            var sql = "SELECT SUM(bytes_in_delta) + SUM(bytes_out_delta) FROM network_samples WHERE ts >= ? AND ts < ?"
            var params: [SQLValue] = [.int(Int64(mid)), .int(Int64(end))]
            if let network { sql += " AND network = ?"; params.append(.text(network)) }
            let rows = (try? await db.query(sql, params)) ?? []
            total += rows.first?.first?.intValue ?? 0
        }

        return total
    }

    func stats() async -> (since: Date?, dbBytes: Int) {
        let rows = (try? await db.query("SELECT MIN(ts) FROM network_samples")) ?? []
        var since: Date?
        if let v = rows.first?.first, v.intValue > 0 {
            since = Date(timeIntervalSince1970: TimeInterval(v.intValue))
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: Constants.Database.fileURL.path)[.size]) as? Int ?? 0
        return (since, size)
    }
}
