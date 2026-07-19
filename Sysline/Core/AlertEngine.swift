import Foundation

// Checks the single data plan after each poll and fires the daily reminder
// at the user's chosen time. Nothing repeats within a cycle / day.
@MainActor
final class AlertEngine {
    static let shared = AlertEngine()

    private let query = NetworkQuery(db: .shared)
    private let d = UserDefaults.standard
    private var lastRun = Date.distantPast

    func evaluate() async {
        let now = Date()
        guard now.timeIntervalSince(lastRun) >= 60 else { return }   // alerts don't need 5s granularity
        lastRun = now

        if d.bool(forKey: "planEnabled") {
            let start = d.double(forKey: "planStart")
            if start > 0 {
                let net = networkFilter
                let used = await query.total(from: Int(start), to: Int(now.timeIntervalSince1970), network: net)
                let notifyBytes = Int(d.double(forKey: "planNotifyGB") * 1_000_000_000)
                let tag = String(Int(start))   // resets when the start date changes
                if notifyBytes > 0, used >= notifyBytes, d.string(forKey: "planFired") != tag {
                    d.set(tag, forKey: "planFired")
                    let limit = Int(d.double(forKey: "planLimitGB"))
                    Notifier.send(id: "plan", title: "Data alert",
                                  body: "You've used \(ByteFormat.string(used)) — nearing your \(limit) GB plan.")
                }
            }
        }

        if d.bool(forKey: "dailyReminder") {
            let today = Self.dayKey()
            if d.string(forKey: "lastDaily") != today {
                let hour = d.integer(forKey: "dailyHour")
                let minute = d.integer(forKey: "dailyMinute")
                if let fireAt = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now),
                   now >= fireAt {
                    d.set(today, forKey: "lastDaily")
                    let used = await query.usage(.today, network: networkFilter).reduce(0) { $0 + $1.total }
                    Notifier.send(id: "daily-\(today)", title: "Today's usage",
                                  body: "You've used \(ByteFormat.string(used)) today.")
                }
            }
        }
    }

    private var networkFilter: String? {
        let net = d.string(forKey: "planNetwork") ?? ""
        return net.isEmpty ? nil : net
    }

    private static func dayKey() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
