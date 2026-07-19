import Foundation
import Combine

@MainActor
final class SpeedViewModel: ObservableObject {
    @Published private(set) var history: [SpeedResult] = []

    private let store = SpeedStore(db: .shared)

    var latest: SpeedResult? { history.first }

    func load() {
        Task { history = await store.history() }
    }
}
