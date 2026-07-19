import SwiftUI
import UserNotifications

struct DataPlanSettings: View {
    @AppStorage("planEnabled") private var enabled = false
    @AppStorage("planStart") private var planStart = 0.0
    @AppStorage("planLimitGB") private var limitGB = 200.0
    @AppStorage("planNotifyGB") private var notifyGB = 190.0
    @AppStorage("planNetwork") private var network = ""
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("dailyHour") private var dailyHour = 9
    @AppStorage("dailyMinute") private var dailyMinute = 0

    @State private var networks: [String] = []
    @State private var used = 0
    @State private var notifDenied = false

    private let query = NetworkQuery(db: .shared)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if (enabled || dailyReminder), notifDenied {
                SettingGroup {
                    PermissionBanner(text: "Notifications are off for Sysline — you won't get these alerts.") {
                        SystemSettings.openNotifications()
                    }
                }
            }

            // 1 — Data plan: notifies once, when you cross your limit.
            SettingGroup("Data Plan") {
                VStack(spacing: 10) {
                    SettingRow(title: "Track my data plan",
                               subtitle: "Get one alert when you reach your limit.",
                               icon: "chart.bar") {
                        SwitchToggle(isOn: enabled) { on in
                            enabled = on
                            if on {
                                if planStart == 0 { planStart = Date().timeIntervalSince1970 }
                                Notifier.requestAuth()
                            }
                        }
                    }
                    if enabled {
                        Divider()
                        SettingRow(title: "Start date", subtitle: "When your package began.", indented: true) {
                            DatePicker("", selection: startBinding, displayedComponents: .date).labelsHidden()
                        }
                        Divider()
                        SettingRow(title: "Plan limit", subtitle: "Your total data allowance.", indented: true) {
                            gbField($limitGB)
                        }
                        Divider()
                        SettingRow(title: "Notify me at", subtitle: "Alert when usage reaches this.", indented: true) {
                            gbField($notifyGB)
                        }
                        Divider()
                        SettingRow(title: "Network", subtitle: "Which connection to count.", indented: true) {
                            Picker("", selection: $network) {
                                Text("Total").tag("")
                                ForEach(networks, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden().frame(width: 130)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: min(Double(used) / max(limitGB * 1_000_000_000, 1), 1))
                                .tint(used >= Int(notifyGB * 1_000_000_000) ? .red : Theme.accent)
                            Text("\(ByteFormat.string(used)) used of \(Int(limitGB)) GB · notify at \(Int(notifyGB)) GB")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .padding(.leading, 32)
                    }
                }
            }

            // 2 — Daily reminder: notifies every day at a set time.
            SettingGroup("Daily Reminder") {
                VStack(spacing: 10) {
                    SettingRow(title: "Daily usage reminder",
                               subtitle: "A notification every day at a time you pick.",
                               icon: "clock") {
                        SwitchToggle(isOn: dailyReminder) { on in
                            dailyReminder = on
                            if on { Notifier.requestAuth() }
                        }
                    }
                    if dailyReminder {
                        Divider()
                        SettingRow(title: "Reminder time",
                                   subtitle: "When your daily usage note arrives.",
                                   indented: true) {
                            DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute).labelsHidden()
                        }
                    }
                }
            }
        }
        .task { await refresh() }
        .onChange(of: network) { Task { await refresh() } }
        .onChange(of: planStart) { Task { await refresh() } }
        .onChange(of: enabled) { Task { await refresh() } }
        .onChange(of: dailyReminder) { Task { await refresh() } }
    }

    private func gbField(_ value: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            TextField("", value: value, format: .number)
                .frame(width: 70).multilineTextAlignment(.trailing)
            Text("GB").foregroundStyle(.secondary)
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { planStart == 0 ? Date() : Date(timeIntervalSince1970: planStart) },
            set: { planStart = $0.timeIntervalSince1970 }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: dailyHour, minute: dailyMinute, second: 0, of: Date()) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                dailyHour = c.hour ?? 9
                dailyMinute = c.minute ?? 0
            }
        )
    }

    private func refresh() async {
        networks = await query.networks()
        let start = planStart == 0 ? Date().timeIntervalSince1970 : planStart
        used = await query.total(from: Int(start), to: Int(Date().timeIntervalSince1970),
                                 network: network.isEmpty ? nil : network)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifDenied = settings.authorizationStatus == .denied
    }
}
