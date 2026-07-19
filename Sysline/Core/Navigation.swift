import SwiftUI
import Combine

@MainActor
final class Navigation: ObservableObject {
    static let shared = Navigation()

    enum Section: Hashable { case network, speed, settings }
    @Published var section: Section? = .network
}
