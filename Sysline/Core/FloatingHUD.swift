import AppKit
import SwiftUI

// Always-on-top mini monitor, hosted in a borderless floating NSPanel.
@MainActor
final class FloatingHUD {
    static let shared = FloatingHUD()
    private var panel: NSPanel?

    func setVisible(_ visible: Bool) { visible ? show() : hide() }

    // Size changed → rebuild so the panel resizes to the new content.
    func reload() { if panel != nil { hide(); show() } }

    // On-top toggle changed → just adjust the window level.
    func applyLevel() { panel?.level = Prefs.hudOnTop ? .floating : .normal }

    private func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        let hosting = NSHostingView(rootView: HUDView())
        hosting.setFrameSize(hosting.fittingSize)

        let p = NSPanel(contentRect: hosting.frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = Prefs.hudOnTop ? .floating : .normal
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = hosting

        if let vf = NSScreen.main?.visibleFrame {
            p.setFrameTopLeftPoint(NSPoint(x: vf.maxX - hosting.frame.width - 20, y: vf.maxY - 20))
        }
        p.orderFrontRegardless()
        panel = p
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
