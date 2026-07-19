import CoreWLAN

// A label for the network active right now, used to tag each sample.
// The real Wi-Fi SSID when Location access is granted; otherwise "Unknown network".
enum CurrentNetwork {
    static func identifier() -> String {
        if let ssid = CWWiFiClient.shared().interface()?.ssid(), !ssid.isEmpty {
            return ssid
        }
        return "Unknown network"
    }
}
