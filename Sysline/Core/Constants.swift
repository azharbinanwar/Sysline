//
//  Constants.swift
//  Sysline
//
//  Central config. Change values HERE — never scatter literals across the app.
//

import Foundation

enum Constants {

    enum App {
        static let name = "Sysline"
    }

    /// Database config. To reset during development:
    ///   • bump `schemaVersion` → triggers a migration/reset, or
    ///   • change `name`        → fresh file, old one left orphaned on disk.
    enum Database {
        static let name = "sysline_v2"
        static let schemaVersion = 2
        static let fileExtension = "sqlite"

        static var fileName: String { "\(name).\(fileExtension)" }

        /// ~/Library/Application Support/Sysline/<name>.sqlite
        static var fileURL: URL {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(App.name, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent(fileName)
        }
    }

    enum Poll {
        static let interval: TimeInterval = 5   // seconds
    }

    /// Retention windows. Raw samples get rolled up hourly, then pruned.
    enum Retention {
        static let rawSampleHours = 48
        static let hourlyDays = 90
    }
}
