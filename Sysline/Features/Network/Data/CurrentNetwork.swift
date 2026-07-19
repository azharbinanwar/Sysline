import CoreWLAN

// A label for the network active right now, used to tag each sample/test.
enum CurrentNetwork {
    // The real Wi-Fi SSID when Location access is granted; otherwise "Unknown network".
    static func identifier() -> String {
        guard let s = CWWiFiClient.shared().interface()?.ssid(), !s.isEmpty else { return "Unknown network" }
        return s
    }
}
