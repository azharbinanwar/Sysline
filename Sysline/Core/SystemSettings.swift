import AppKit

// Deep links to the exact System Settings privacy panes. Needed because once a
// permission is denied, request() no longer prompts — the user must flip it here.
enum SystemSettings {
    static func openLocation() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
    }

    static func openNotifications() {
        open("x-apple.systempreferences:com.apple.preference.notifications")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
