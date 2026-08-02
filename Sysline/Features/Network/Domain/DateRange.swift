//
//  DateRange.swift
//  Sysline
//
//  Selectable range for the Network popover. Queries will map these to
//  epoch bounds later; for now the UI just drives mock data.
//

import Foundation

enum DateRange: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case week = "7 Days"
    case month = "30 Days"
    case quarter = "90 Days"
    case all = "All"

    var id: String { rawValue }

    // The single source of truth for which surfaces show which ranges:
    // glance surfaces (menu-bar popover, floating HUD) stay light; the main
    // window offers every case including the long, heavier ranges.
    static let glance: [DateRange] = [.today, .yesterday, .week, .month]

    // Cycle to the next glance range (wraps) — used by the HUD's tap-to-swap.
    var next: DateRange {
        let ranges = Self.glance
        let index = ranges.firstIndex(of: self) ?? 0
        return ranges[(index + 1) % ranges.count]
    }

    // Today/Yesterday are within raw-sample retention; longer ranges use hourly.
    var usesRawSamples: Bool { self == .today || self == .yesterday }

    // [start, end) as unix seconds.
    func bounds(now: Date = Date(), calendar: Calendar = .current) -> (Int, Int) {
        let startToday = calendar.startOfDay(for: now)
        func e(_ d: Date) -> Int { Int(d.timeIntervalSince1970) }
        switch self {
        case .today:
            return (e(startToday), e(now))
        case .yesterday:
            let y = calendar.date(byAdding: .day, value: -1, to: startToday) ?? startToday
            return (e(y), e(startToday))
        case .week:
            let s = calendar.date(byAdding: .day, value: -7, to: startToday) ?? startToday
            return (e(s), e(now))
        case .month:
            let s = calendar.date(byAdding: .day, value: -30, to: startToday) ?? startToday
            return (e(s), e(now))
        case .quarter:
            let s = calendar.date(byAdding: .day, value: -90, to: startToday) ?? startToday
            return (e(s), e(now))
        case .all:
            return (0, e(now))
        }
    }
}
