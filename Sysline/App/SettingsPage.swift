import SwiftUI

struct SettingsPage: View {
    @State private var tab = 0   // 0 = App, 1 = Network

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("App").tag(0)
                Text("Network").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(12)

            ScrollView {
                Group {
                    if tab == 0 { AppSettingsSection() } else { NetworkSettingsSection() }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct AppSettingsSection: View {
    @AppStorage("theme") private var theme = 0
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = false
    @AppStorage("showFloatingHUD") private var showHUD = false
    @AppStorage("hudSize") private var hudSize = 0
    @AppStorage("hudOnTop") private var hudOnTop = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingGroup("Floating Monitor") {
                VStack(spacing: 10) {
                    SettingRow(title: "Show floating monitor",
                               subtitle: "A small window with live usage.",
                               icon: "macwindow.on.rectangle") {
                        SwitchToggle(isOn: showHUD) { on in
                            showHUD = on
                            FloatingHUD.shared.setVisible(on)
                        }
                    }
                    if showHUD {
                        Divider()
                        SettingRow(title: "Size",
                                   subtitle: "Small shows totals; larger adds top apps and a chart.",
                                   indented: true) {
                            Picker("", selection: $hudSize) {
                                Text("Small").tag(0); Text("Medium").tag(1); Text("Large").tag(2)
                            }
                            .labelsHidden().pickerStyle(.segmented).fixedSize()
                            .onChange(of: hudSize) { FloatingHUD.shared.reload() }
                        }
                        Divider()
                        SettingRow(title: "Always on top",
                                   subtitle: "Off lets other windows cover it.",
                                   indented: true) {
                            SwitchToggle(isOn: hudOnTop) { on in
                                hudOnTop = on
                                FloatingHUD.shared.applyLevel()
                            }
                        }
                    }
                }
            }

            SettingGroup("Appearance") {
                SettingRow(title: "Theme",
                           subtitle: "System follows macOS; Light or Dark forces it.",
                           icon: "paintbrush") {
                    Picker("", selection: $theme) {
                        Text("System").tag(0); Text("Light").tag(1); Text("Dark").tag(2)
                    }
                    .labelsHidden().frame(width: 120)
                }
            }

            SettingGroup("Startup") {
                VStack(spacing: 10) {
                    SettingRow(title: "Launch at login",
                               subtitle: "Start Sysline when you log in.",
                               icon: "power") {
                        SwitchToggle(isOn: launchAtLogin) { launchAtLogin = $0; LoginItem.set($0) }
                    }
                    Divider()
                    SettingRow(title: "Show in Dock",
                               subtitle: "Off keeps Sysline menu-bar only.",
                               icon: "dock.rectangle") {
                        SwitchToggle(isOn: showDockIcon) {
                            showDockIcon = $0
                            NSApp.setActivationPolicy($0 ? .regular : .accessory)
                        }
                    }
                }
            }

            UpdatesSection()

            SettingGroup("About") {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                            .resizable().frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sysline").font(.system(size: 14, weight: .semibold))
                            Text("See which apps use your internet, over time.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(versionText).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Divider()
                    SettingRow(title: "Source & issues",
                               subtitle: "Open source on GitHub · MIT license.",
                               icon: "chevron.left.forwardslash.chevron.right") {
                        Button("GitHub") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/azharbinanwar/Sysline")!)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(v) (\(b))"
    }
}

private struct UpdatesSection: View {
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        SettingGroup("Updates") {
            SettingRow(title: "Sysline \(updater.currentVersion)",
                       subtitle: statusText,
                       icon: "arrow.triangle.2.circlepath") {
                trailing
            }
        }
    }

    @ViewBuilder private var trailing: some View {
        switch updater.phase {
        case .checking:
            ProgressView().controlSize(.small)
        case .downloading(let p):
            ProgressView(value: p).frame(width: 90)
        case .installing:
            Text("Installing…").font(.caption).foregroundStyle(.secondary)
        case .available:
            Button("Update & Relaunch") { Task { await updater.downloadAndInstall() } }
                .buttonStyle(.borderedProminent).controlSize(.small)
        default:
            Button("Check for Updates") { Task { await updater.check() } }
                .controlSize(.small)
        }
    }

    private var statusText: String {
        switch updater.phase {
        case .available(let v): "Version \(v) is available."
        case .upToDate: "You're up to date."
        case .failed(let m): m
        default: "Checks automatically once a day."
        }
    }
}

private struct NetworkSettingsSection: View {
    @AppStorage("pollInterval") private var pollInterval = 5.0
    @AppStorage("paused") private var paused = false
    @AppStorage("retentionDays") private var retentionDays = 90
    @AppStorage("networkBreakdown") private var breakdown = false
    @ObservedObject private var location = LocationAuth.shared
    @State private var since: Date?
    @State private var dbBytes = 0
    @State private var confirmClear = false

    private let query = NetworkQuery(db: .shared)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingGroup("Wi-Fi") {
                VStack(spacing: 10) {
                    SettingRow(title: "Break down by network",
                               subtitle: "See usage per Wi-Fi network. Needs Location access to read network names.",
                               icon: "wifi") {
                        SwitchToggle(isOn: breakdown) { on in
                            breakdown = on
                            if on { location.request() }
                        }
                    }
                    if breakdown {
                        if location.granted {
                            InfoNote(systemImage: "checkmark.circle",
                                     text: "Location access granted — network names appear as new data is recorded.")
                        } else {
                            PermissionBanner(text: "Location access is needed to read Wi-Fi network names.") {
                                SystemSettings.openLocation()
                            }
                        }
                    }
                }
            }

            SettingGroup("Recording") {
                VStack(spacing: 10) {
                    SettingRow(title: "Poll interval",
                               subtitle: "How often usage is sampled.",
                               icon: "timer") {
                        Picker("", selection: $pollInterval) {
                            Text("2s").tag(2.0); Text("5s").tag(5.0)
                            Text("10s").tag(10.0); Text("30s").tag(30.0)
                        }
                        .labelsHidden().frame(width: 100)
                    }
                    Divider()
                    SettingRow(title: "Pause recording",
                               subtitle: "Temporarily stop sampling.",
                               icon: "pause.circle") {
                        SwitchToggle(isOn: paused) { paused = $0 }
                    }
                    InfoNote(systemImage: "bolt",
                             text: "Shorter intervals are more accurate but use a little more power.")
                }
            }

            SettingGroup("Data") {
                VStack(spacing: 10) {
                    SettingRow(title: "Keep history",
                               subtitle: "Older data is removed automatically.",
                               icon: "clock.arrow.circlepath") {
                        Picker("", selection: $retentionDays) {
                            Text("30 days").tag(30); Text("90 days").tag(90); Text("365 days").tag(365)
                        }
                        .labelsHidden().frame(width: 110)
                    }
                    Divider()
                    SettingRow(title: "Recording since",
                               subtitle: "When Sysline first started recording.",
                               icon: "calendar") {
                        Text(since?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Divider()
                    SettingRow(title: "Database size",
                               subtitle: "Disk space your saved history uses.",
                               icon: "internaldrive") {
                        Text(ByteFormat.string(dbBytes))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Divider()
                    SettingRow(title: "Clear history",
                               subtitle: "Delete all recorded usage.",
                               icon: "trash") {
                        Button("Clear…", role: .destructive) { confirmClear = true }
                    }
                }
            }

            DataPlanSettings()
        }
        .task { await refresh() }
        .confirmationDialog("Delete all recorded usage?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                Task {
                    await NetworkStore(db: .shared).clearAll()
                    NotificationCenter.default.post(name: .syslineDataChanged, object: nil)
                    await refresh()
                }
            }
        } message: {
            Text("This permanently removes all history. It can't be undone.")
        }
    }

    private func refresh() async {
        let s = await query.stats()
        since = s.since
        dbBytes = s.dbBytes
    }
}
