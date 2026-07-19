import Foundation
import Combine

@MainActor
final class NetworkViewModel: ObservableObject {
    @Published var range: DateRange = .today { didSet { reload() } }
    @Published var networkFilter: String? = nil { didSet { reload() } }  // upcoming Wi-Fi filter
    @Published var searchText = ""
    @Published private(set) var apps: [AppUsage] = []
    @Published private(set) var trend: [UsagePoint] = []
    @Published private(set) var networks: [String] = []

    private let query = NetworkQuery(db: .shared)
    private var cancellable: AnyCancellable?
    private var isActive = false          // only refresh while the view is on screen

    init() {
        cancellable = NotificationCenter.default.publisher(for: .syslineDataChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.isActive == true else { return }
                self?.reload()
            }
    }

    // Called from onAppear/onDisappear so hidden surfaces stop querying.
    func setActive(_ active: Bool) {
        isActive = active
        if active { reload() }
    }

    var totalIn: Int { apps.reduce(0) { $0 + $1.bytesIn } }
    var totalOut: Int { apps.reduce(0) { $0 + $1.bytesOut } }
    var grandTotal: Int { apps.reduce(0) { $0 + $1.total } }
    var topFive: [AppUsage] { Array(apps.prefix(5)) }

    var filteredApps: [AppUsage] {
        searchText.isEmpty ? apps
            : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func percent(_ app: AppUsage) -> Int {
        grandTotal == 0 ? 0 : Int((Double(app.total) / Double(grandTotal) * 100).rounded())
    }

    func reload() { Task { await load() } }

    private func load() async {
        async let a = query.usage(range, network: networkFilter)
        async let t = query.trend(range, network: networkFilter)
        async let n = query.networks()
        apps = await a
        trend = await t
        networks = await n
    }
}
