import SwiftUI

struct MainWindowView: View {
    @StateObject private var vm = NetworkViewModel()
    @ObservedObject private var nav = Navigation.shared
    @AppStorage("theme") private var theme = 0
    @State private var windowWidth: CGFloat = 1000

    // Each toolbar control compacts ITSELF as the window narrows, with wide
    // safety margins so AppKit's » overflow can never trigger:
    //   ≥ 1350  full segmented bar + wifi icon with network name + labels
    //   ≥ 1050  full segmented bar + wifi icon only
    //   below   compact range dropdown + wifi icon only
    private static let wifiLabelMinWidth: CGFloat = 1350
    private static let segmentedMinWidth: CGFloat = 1050

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.section) {
                Label("Network", systemImage: "network").tag(Navigation.Section.network)
                Label("Speed", systemImage: "speedometer").tag(Navigation.Section.speed)
                Label("Settings", systemImage: "gearshape").tag(Navigation.Section.settings)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            detail
        }
        // Min width sized so even the expanded search field plus the compact
        // controls always fit — the toolbar's » overflow must never trigger.
        .frame(minWidth: 880, minHeight: 480)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { windowWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { windowWidth = proxy.size.width }
        })
        .preferredColorScheme(Theme.colorScheme(theme))
        .onAppear { vm.setActive(true) }
        .onDisappear { vm.setActive(false) }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $vm.range) {
            ForEach(DateRange.allCases) { Text($0.rawValue).tag($0) }
        }
        .fixedSize()
    }

    // Menu checkmark binding: the chosen network reads as checked.
    private func networkChoice(_ network: String?) -> Binding<Bool> {
        Binding(get: { vm.networkFilter == network },
                set: { if $0 { vm.networkFilter = network } })
    }

    @ViewBuilder
    private var detail: some View {
        switch nav.section {
        case .settings:
            SettingsPage()
                .navigationTitle("Settings")
        case .speed:
            SpeedView()
        default:
            NetworkDetailView(vm: vm)
                .navigationTitle("Network")
                .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Search apps")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        if windowWidth >= Self.segmentedMinWidth {
                            rangePicker.pickerStyle(.segmented)
                        } else {
                            rangePicker.pickerStyle(.menu)
                        }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Toggle("All Networks", isOn: networkChoice(nil))
                            if !vm.networks.isEmpty {
                                Divider()
                                ForEach(vm.networks, id: \.self) { net in
                                    Toggle(net, isOn: networkChoice(net))
                                }
                            }
                        } label: {
                            if windowWidth >= Self.wifiLabelMinWidth {
                                Label(vm.networkFilter ?? "All Networks", systemImage: "wifi")
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Image(systemName: "wifi")
                            }
                        }
                        Button { vm.reload() } label: {
                            if windowWidth >= Self.wifiLabelMinWidth {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
        }
    }
}
