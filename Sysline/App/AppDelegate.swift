import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "planLimitGB": 200.0, "planNotifyGB": 190.0,
            "dailyHour": 9, "dailyMinute": 0,
            "hudSize": 0, "hudOnTop": true,
        ])
        updateActivationPolicy()
        PollScheduler.shared.start()
        if Prefs.showFloatingHUD { FloatingHUD.shared.setVisible(true) }
        Task { await UpdateChecker.shared.checkIfDue() }
    }

    // Menu-bar-only (accessory) unless the user pinned a Dock icon on.
    private func updateActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = Prefs.showDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }
}
