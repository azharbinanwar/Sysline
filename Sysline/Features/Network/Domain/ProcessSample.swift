//
//  ProcessSample.swift
//  Sysline
//
//  One process's *cumulative* byte counters, as reported by nettop.
//

import Foundation

struct ProcessSample: Equatable, Sendable {
    let name: String
    let pid: Int
    let bytesIn: Int      // cumulative since the process started
    let bytesOut: Int     // cumulative since the process started
}
