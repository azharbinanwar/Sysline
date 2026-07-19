import Foundation

struct AppUsage: Identifiable, Equatable, Sendable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let bytesIn: Int
    let bytesOut: Int

    var total: Int { bytesIn + bytesOut }
}
