import Foundation

// Pure output of the delta math — just process + bytes, no app resolution yet.
struct RawDelta: Sendable, Equatable {
    let name: String
    let pid: Int
    let bytesInDelta: Int
    let bytesOutDelta: Int
}

// A raw delta enriched with app identity + metadata, ready to persist.
struct SampleDelta: Sendable {
    let ts: Int
    let bundleID: String
    let appName: String
    let pid: Int
    let network: String
    let bytesInDelta: Int
    let bytesOutDelta: Int
}
