import CoreLocation
import Combine

// Wi-Fi SSID names require Location access on macOS. This wraps the request
// and exposes the current authorization state.
@MainActor
final class LocationAuth: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAuth()

    private let manager = CLLocationManager()
    @Published private(set) var status: CLAuthorizationStatus

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func request() { manager.requestWhenInUseAuthorization() }

    var granted: Bool { status == .authorizedAlways || status == .authorized }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.status = s }
    }
}
