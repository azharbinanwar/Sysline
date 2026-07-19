import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "planLimitGB": 200.0, "planNotifyGB": 190.0,
            "dailyHour": 9, "dailyMinute": 0,
            "hudSize": 0, "hudOnTop": true,
        ])
        NSApp.setActivationPolicy(Prefs.showDockIcon ? .regular : .accessory)
        PollScheduler.shared.start()
        if Prefs.showFloatingHUD { FloatingHUD.shared.setVisible(true) }
        Task { await UpdateChecker.shared.checkIfDue() }
    }
}
