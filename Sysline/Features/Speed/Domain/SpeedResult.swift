import Foundation

struct SpeedResult: Identifiable, Sendable, Equatable {
    let id: Int64
    let date: Date
    let downMbps: Double
    let upMbps: Double
    let pingMs: Int
    let jitterMs: Int
    let network: String
    let isp: String
    let place: String
}

// A 0–5 quality score per activity, shown as icon + dots (Speedtest-style).
struct SpeedRating: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let score: Int   // 0…5

    static func all(down: Double, up: Double, ping: Int) -> [SpeedRating] {
        [
            SpeedRating(icon: "cursorarrow.rays", label: "Browsing",    score: browsing(down, ping)),
            SpeedRating(icon: "gamecontroller",   label: "Gaming",      score: gaming(ping)),
            SpeedRating(icon: "play.rectangle",   label: "Streaming",   score: streaming(down)),
            SpeedRating(icon: "video",            label: "Video calls", score: calls(down: down, up: up, ping: ping)),
        ]
    }

    // score 0 = not measured yet (values still zero), so tiles fill in as the test runs
    private static func browsing(_ down: Double, _ ping: Int) -> Int {
        if down < 1 { return 0 }
        if ping <= 30, down >= 5 { return 5 }
        if ping <= 60, down >= 3 { return 4 }
        if ping <= 100 { return 3 }
        if ping <= 200 { return 2 }
        return 1
    }
    private static func gaming(_ ping: Int) -> Int {
        if ping <= 0 { return 0 }
        if ping <= 20 { return 5 }
        if ping <= 45 { return 4 }
        if ping <= 70 { return 3 }
        if ping <= 120 { return 2 }
        return 1
    }
    private static func streaming(_ down: Double) -> Int {
        if down < 1 { return 0 }
        if down >= 25 { return 5 }
        if down >= 15 { return 4 }
        if down >= 8 { return 3 }
        if down >= 3 { return 2 }
        return 1
    }
    private static func calls(down: Double, up: Double, ping: Int) -> Int {
        let band = min(down, up)
        if band < 0.5 { return 0 }
        var s = band >= 6 ? 5 : band >= 3 ? 4 : band >= 1.5 ? 3 : 2
        if ping > 200 { s = max(1, s - 2) } else if ping > 100 { s = max(1, s - 1) }
        return s
    }
}
