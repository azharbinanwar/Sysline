//
//  NetworkView.swift
//  Sysline
//
//  The Network module's popover content.
//

import SwiftUI

struct NetworkView: View {
    @StateObject private var vm = NetworkViewModel()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showFloatingHUD") private var showHUD = false
    @State private var showAll = false

    private let collapsedCount = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            rangePicker
            totalRow
            Divider()
            appList
            if !vm.apps.isEmpty {
                Text("Top apps").font(.caption).foregroundStyle(.secondary)
                UsageChartView(apps: vm.topFive)
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { vm.reload() }
    }

    private var rangePicker: some View {
        Picker("", selection: $vm.range) {
            ForEach(DateRange.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var totalRow: some View {
        HStack {
            Label(ByteFormat.string(vm.totalIn), systemImage: "arrow.down")
                .foregroundStyle(.primary)
            Spacer()
            Label(ByteFormat.string(vm.totalOut), systemImage: "arrow.up")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 15, weight: .semibold))
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
            let shown = showAll ? vm.apps : Array(vm.apps.prefix(collapsedCount))
            VStack(spacing: 0) {
                ForEach(shown) { AppRowView(app: $0) }
            }
            if vm.apps.count > collapsedCount {
                Button(showAll ? "Show less" : "Show all (\(vm.apps.count))") {
                    showAll.toggle()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Recording since Jul 19")   // ponytail: wire to first sample date in Phase 3
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Open Sysline") { openWindow(id: "main") }
                Toggle("Floating Monitor", isOn: Binding(
                    get: { showHUD },
                    set: { showHUD = $0; FloatingHUD.shared.setVisible($0) }))
                Button("Settings…") {
                    openWindow(id: "main")
                    Navigation.shared.section = .settings
                }
                Button("Quit Sysline") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
