import Foundation
import SQLite3

enum SQLValue: Sendable {
    case int(Int64)
    case text(String)
    case null

    var intValue: Int { if case let .int(v) = self { return Int(v) }; return 0 }
    var textValue: String { if case let .text(v) = self { return v }; return "" }
}

enum DBError: Error { case open(String), prepare(String), step(String), exec(String) }

// Thin SQLite wrapper. An actor so all access is serialized on one connection.
actor Database {
    static let shared = try! Database()

    private let handle: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(path: URL = Constants.Database.fileURL) throws {
        var h: OpaquePointer?
        guard sqlite3_open(path.path, &h) == SQLITE_OK else {
            throw DBError.open(String(cString: sqlite3_errmsg(h)))
        }
        handle = h
        try Database.exec(h, "PRAGMA journal_mode = WAL;")
        try Database.exec(h, Database.schemaSQL)
    }

    func run(_ sql: String, _ params: [SQLValue] = []) throws {
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DBError.step(String(cString: sqlite3_errmsg(handle)))
        }
    }

    func query(_ sql: String, _ params: [SQLValue] = []) throws -> [[SQLValue]] {
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        var rows: [[SQLValue]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let count = sqlite3_column_count(stmt)
            var row: [SQLValue] = []
            row.reserveCapacity(Int(count))
            for c in 0..<count {
                switch sqlite3_column_type(stmt, c) {
                case SQLITE_INTEGER:
                    row.append(.int(sqlite3_column_int64(stmt, c)))
                case SQLITE_TEXT:
                    row.append(.text(sqlite3_column_text(stmt, c).map { String(cString: $0) } ?? ""))
                default:
                    row.append(.null)
                }
            }
            rows.append(row)
        }
        return rows
    }

    // Runs many statements in one transaction, on the actor.
    func writeBatch(_ statements: [(String, [SQLValue])]) throws {
        try exec("BEGIN;")
        do {
            for (sql, params) in statements { try run(sql, params) }
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    // MARK: - Private

    private func prepare(_ sql: String, _ params: [SQLValue]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            switch p {
            case .int(let v):  sqlite3_bind_int64(stmt, idx, v)
            case .text(let v): sqlite3_bind_text(stmt, idx, v, -1, transient)
            case .null:        sqlite3_bind_null(stmt, idx)
            }
        }
        return stmt
    }

    private func exec(_ sql: String) throws { try Database.exec(handle, sql) }

    private nonisolated static func exec(_ handle: OpaquePointer?, _ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &err) == SQLITE_OK else {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw DBError.exec(msg)
        }
    }

    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS network_samples (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        ts              INTEGER NOT NULL,
        bundle_id       TEXT    NOT NULL,
        app_name        TEXT    NOT NULL,
        pid             INTEGER NOT NULL,
        network         TEXT    NOT NULL,
        bytes_in_delta  INTEGER NOT NULL,
        bytes_out_delta INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_ns_ts        ON network_samples(ts);
    CREATE INDEX IF NOT EXISTS idx_ns_bundle_ts ON network_samples(bundle_id, ts);

    CREATE TABLE IF NOT EXISTS network_hourly (
        hour_start INTEGER NOT NULL,
        bundle_id  TEXT    NOT NULL,
        app_name   TEXT    NOT NULL,
        network    TEXT    NOT NULL,
        bytes_in   INTEGER NOT NULL,
        bytes_out  INTEGER NOT NULL,
        PRIMARY KEY (hour_start, bundle_id, network)
    );
    PRAGMA user_version = \(Constants.Database.schemaVersion);
    """
}
