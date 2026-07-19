import AppKit

enum AppIcon {
    static let otherBundleID = "__other__"

    static func image(for bundleID: String) -> NSImage {
        if bundleID != otherBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "cpu", accessibilityDescription: "Other") ?? NSImage()
    }
}
