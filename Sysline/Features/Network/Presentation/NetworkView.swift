import SwiftUI

// The menu-bar popover: a quick glance at usage.
struct NetworkView: View {
    @StateObject private var vm = NetworkViewModel()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showFloatingHUD") private var showHUD = false
    @State private var since: Date?

    private let topCount = 8
    private let query = NetworkQuery(db: .shared)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            rangePicker
            totalRow
            Divider()
            appList
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            vm.setActive(true)
            Task { since = await query.stats().since }
        }
        .onDisappear { vm.setActive(false) }
    }

    private var rangePicker: some View {
        Picker("", selection: $vm.range) {
            ForEach(DateRange.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var totalRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("↓ \(ByteFormat.string(vm.totalIn))")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.down)
                Text("Downloaded").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("↑ \(ByteFormat.string(vm.totalOut))")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.up)
                Text("Uploaded").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
    }

    @ViewBuilder
    private var appList: some View {
        if vm.apps.isEmpty {
            Text("No data yet — Sysline just started recording.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                ForEach(vm.apps.prefix(topCount)) { AppRowView(app: $0) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let since {
                Text("Recording since \(since.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: { Image(systemName: "macwindow") }
                .help("Open Sysline window")
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "speedtest")
            } label: { Image(systemName: "speedometer") }
                .help("Run speed test")
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
                Navigation.shared.section = .settings
            } label: { Image(systemName: "gearshape") }
                .help("Settings")
            Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
                .help("Quit Sysline")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
