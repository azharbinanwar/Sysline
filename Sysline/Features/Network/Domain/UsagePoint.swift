//
//  UsagePoint.swift
//  Sysline
//
//  One point on the usage-over-time trend chart. Fed by mock now, by the
//  hourly rollup query later.
//

import Foundation

struct UsagePoint: Identifiable, Sendable {
    let date: Date
    let bytesIn: Int
    let bytesOut: Int
    var id: Date { date }
}
