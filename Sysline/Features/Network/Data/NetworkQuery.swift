import Foundation

// Reads. Today/Yesterday come from raw samples (accurate); 7/30 Days from the
// hourly rollup (misses at most the current in-progress hour — negligible).
struct NetworkQuery {
    let db: Database

    func usage(_ range: DateRange, network: String?) async -> [AppUsage] {
        let (start, end) = range.bounds()
        let table = range.usesRawSamples ? "network_samples" : "network_hourly"
        let inCol = range.usesRawSamples ? "bytes_in_delta" : "bytes_in"
        let outCol = range.usesRawSamples ? "bytes_out_delta" : "bytes_out"
        let timeCol = range.usesRawSamples ? "ts" : "hour_start"

        var sql = "SELECT bundle_id, MAX(app_name), SUM(\(inCol)), SUM(\(outCol)) FROM \(table) WHERE \(timeCol) >= ? AND \(timeCol) < ?"
        var params: [SQLValue] = [.int(Int64(start)), .int(Int64(end))]
        if let network { sql += " AND network = ?"; params.append(.text(network)) }
        sql += " GROUP BY bundle_id"

        let rows = (try? await db.query(sql, params)) ?? []
        return rows
            .compactMap { r -> AppUsage? in
                guard r.count >= 4 else { return nil }
                return AppUsage(bundleID: r[0].textValue, name: r[1].textValue,
                                bytesIn: r[2].intValue, bytesOut: r[3].intValue)
            }
            .sorted { $0.total > $1.total }
    }

    func trend(_ range: DateRange, network: String?) async -> [UsagePoint] {
        let (start, end) = range.bounds()
        let raw = range.usesRawSamples
        let table = raw ? "network_samples" : "network_hourly"
        let inCol = raw ? "bytes_in_delta" : "bytes_in"
        let outCol = raw ? "bytes_out_delta" : "bytes_out"
        let timeCol = raw ? "ts" : "hour_start"
        let bucket = raw ? 3600 : 86400   // hourly points for days, daily for weeks/months

        var sql = "SELECT (\(timeCol)/\(bucket))*\(bucket) AS b, SUM(\(inCol)), SUM(\(outCol)) FROM \(table) WHERE \(timeCol) >= ? AND \(timeCol) < ?"
        var params: [SQLValue] = [.int(Int64(start)), .int(Int64(end))]
        if let network { sql += " AND network = ?"; params.append(.text(network)) }
        sql += " GROUP BY b ORDER BY b"

        let rows = (try? await db.query(sql, params)) ?? []
        return rows.compactMap { r -> UsagePoint? in
            guard r.count >= 3 else { return nil }
            return UsagePoint(date: Date(timeIntervalSince1970: TimeInterval(r[0].intValue)),
                              bytesIn: r[1].intValue, bytesOut: r[2].intValue)
        }
    }

    func networks() async -> [String] {
        let rows = (try? await db.query("SELECT DISTINCT network FROM network_samples ORDER BY network")) ?? []
        return rows.compactMap { $0.first?.textValue }.filter { !$0.isEmpty }
    }

    // Total bytes over an arbitrary window — used by reminders/budgets.
    func total(from start: Int, to end: Int, network: String?) async -> Int {
        let raw = start >= Int(Date().timeIntervalSince1970) - Constants.Retention.rawSampleHours * 3600
        let table = raw ? "network_samples" : "network_hourly"
        let inCol = raw ? "bytes_in_delta" : "bytes_in"
        let outCol = raw ? "bytes_out_delta" : "bytes_out"
        let timeCol = raw ? "ts" : "hour_start"

        var sql = "SELECT SUM(\(inCol)) + SUM(\(outCol)) FROM \(table) WHERE \(timeCol) >= ? AND \(timeCol) < ?"
        var params: [SQLValue] = [.int(Int64(start)), .int(Int64(end))]
        if let network { sql += " AND network = ?"; params.append(.text(network)) }

        let rows = (try? await db.query(sql, params)) ?? []
        return rows.first?.first?.intValue ?? 0
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
