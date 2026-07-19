//
//  ByteFormat.swift
//  Sysline
//
//  Single place that turns byte counts into human strings. Decimal (SI)
//  units — matches how ISPs / data plans report usage.
//

import Foundation

enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file            // 1000-based, e.g. "4.2 GB"
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f
    }()

    static func string(_ bytes: Int) -> String {
        formatter.string(fromByteCount: Int64(max(0, bytes)))
    }
}
