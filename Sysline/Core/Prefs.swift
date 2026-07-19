import Foundation

// Typed read access to user preferences for non-view code (scheduler, store).
// The Settings views edit the same keys via @AppStorage.
enum Prefs {
    private static let d = UserDefaults.standard

    static var pollInterval: Double { let v = d.double(forKey: "pollInterval"); return v > 0 ? v : 5 }
    static var retentionDays: Int { let v = d.integer(forKey: "retentionDays"); return v > 0 ? v : 90 }
    static var paused: Bool { d.bool(forKey: "paused") }
    static var launchAtLogin: Bool { d.bool(forKey: "launchAtLogin") }
    static var theme: Int { d.integer(forKey: "theme") }   // 0 System, 1 Light, 2 Dark
    static var networkBreakdown: Bool { d.bool(forKey: "networkBreakdown") }
    static var showFloatingHUD: Bool { d.bool(forKey: "showFloatingHUD") }
    static var hudSize: Int { d.integer(forKey: "hudSize") }   // 0 small, 1 medium, 2 large
    static var hudOnTop: Bool { d.object(forKey: "hudOnTop") == nil ? true : d.bool(forKey: "hudOnTop") }
    static var alertsEnabled: Bool { d.bool(forKey: "alertsEnabled") }
    static var dailySummary: Bool { d.bool(forKey: "dailySummary") }
    static var newNetworkAlert: Bool { d.bool(forKey: "newNetworkAlert") }
    // Off by default: menu-bar-only, no Dock burden. Users can opt into a Dock icon.
    static var showDockIcon: Bool { d.bool(forKey: "showDockIcon") }
}
