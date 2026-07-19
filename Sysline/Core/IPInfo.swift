import Foundation

// Coarse location + carrier/ISP from the public IP — free, no key, no permission.
// Over a hotspot this reports the mobile carrier (e.g. "Jazz") and its gateway city.
enum IPInfo {
    struct Result: Sendable { let place: String; let isp: String }

    static func fetch() async -> Result? {
        guard let url = URL(string: "https://ipwho.is/"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              j["success"] as? Bool == true else { return nil }

        let city = j["city"] as? String ?? ""
        let country = j["country"] as? String ?? ""
        let conn = j["connection"] as? [String: Any]
        let isp = (conn?["isp"] as? String) ?? (conn?["org"] as? String) ?? ""
        let place = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        return Result(place: place.isEmpty ? country : place, isp: isp)
    }
}
