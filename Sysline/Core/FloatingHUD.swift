import AppKit
import SwiftUI

// Mini monitor in a borderless NSPanel. The "on top" toggle decides whether it
// floats above everything (full-screen apps included) or acts like a normal window.
@MainActor
final class FloatingHUD {
    static let shared = FloatingHUD()
    private var panel: NSPanel?
    private let positionKey = "hudTopLeft"

    func setVisible(_ visible: Bool) { visible ? show() : hide() }

    // Size changed → rebuild so the panel resizes to the new content.
    func reload() { if panel != nil { hide(); show() } }

    private func applyOnTop(_ panel: NSPanel) {
        let onTop = Prefs.hudOnTop
        panel.isFloatingPanel = onTop
        panel.level = onTop ? .floating : .normal
        // Off = a plain managed window: one desktop, hidden by other apps, never
        // in full-screen spaces. .canJoinAllSpaces would leak it into full-screen
        // spaces on modern macOS no matter what other flags are set.
        panel.collectionBehavior = onTop ? [.canJoinAllSpaces, .fullScreenAuxiliary]
                                         : [.managed, .fullScreenNone]
    }

    private func show() {
        if let panel {
            order(panel)
            return
        }
        let hosting = NSHostingView(rootView: HUDView())
        hosting.setFrameSize(hosting.fittingSize)

        let p = NSPanel(contentRect: hosting.frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        applyOnTop(p)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.contentView = hosting

        p.setFrameTopLeftPoint(savedTopLeft ?? defaultTopLeft(width: hosting.frame.width))
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p,
                                               queue: .main) { [weak p, positionKey] _ in
            guard let p else { return }
            let topLeft = NSPoint(x: p.frame.minX, y: p.frame.maxY)
            UserDefaults.standard.set(NSStringFromPoint(topLeft), forKey: positionKey)
        }
        order(p)
        panel = p
    }

    // "Regardless" forces a window in front across every space — only right
    // for the on-top overlay; a normal window gets a normal orderFront.
    private func order(_ panel: NSPanel) {
        if Prefs.hudOnTop { panel.orderFrontRegardless() } else { panel.orderFront(nil) }
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    // Last dragged position, ignored if it's no longer on any connected screen.
    private var savedTopLeft: NSPoint? {
        guard let stored = UserDefaults.standard.string(forKey: positionKey) else { return nil }
        let point = NSPointFromString(stored)
        let onScreen = NSScreen.screens.contains { NSPointInRect(point, $0.visibleFrame) }
        return onScreen ? point : nil
    }

    private func defaultTopLeft(width: CGFloat) -> NSPoint {
        guard let visibleFrame = NSScreen.main?.visibleFrame else { return NSPoint(x: 100, y: 500) }
        return NSPoint(x: visibleFrame.maxX - width - 20, y: visibleFrame.maxY - 20)
    }
}
