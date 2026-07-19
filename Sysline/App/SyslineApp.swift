import SwiftUI

@main
struct SyslineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        #if DEBUG
        RenderShot.runIfRequested()
        NetworkPoller.runSelfTestIfRequested()
        #endif
    }

    var body: some Scene {
        Window("Sysline", id: "main") {
            MainWindowView()
        }
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { Navigation.shared.section = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

        // Standalone speed-test dialog the menu can open without launching the app.
        Window("Speed Test", id: "speedtest") {
            SpeedTestSheet(network: CurrentNetwork.identifier()) {}
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra("Sysline", image: "MenuIcon") {
            MenuContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
