import ServiceManagement

enum LoginItem {
    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Sysline login item error: \(error.localizedDescription)")
        }
    }
}
