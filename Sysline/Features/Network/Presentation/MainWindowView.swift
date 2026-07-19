import SwiftUI

struct MainWindowView: View {
    @StateObject private var vm = NetworkViewModel()
    @ObservedObject private var nav = Navigation.shared
    @AppStorage("theme") private var theme = 0

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
        .frame(minWidth: 760, minHeight: 480)
        .preferredColorScheme(Theme.colorScheme(theme))
        .onAppear { vm.setActive(true) }
        .onDisappear { vm.setActive(false) }
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
                        Picker("Range", selection: $vm.range) {
                            ForEach(DateRange.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Menu {
                            Button("All Networks") { vm.networkFilter = nil }
                            if !vm.networks.isEmpty {
                                Divider()
                                ForEach(vm.networks, id: \.self) { net in
                                    Button(net) { vm.networkFilter = net }
                                }
                            }
                        } label: {
                            Label(vm.networkFilter ?? "All Networks", systemImage: "wifi")
                                .labelStyle(.titleAndIcon)
                        }
                        Button { vm.reload() } label: { Image(systemName: "arrow.clockwise") }
                    }
                }
        }
    }
}
