import CoreLocation
import Observation

/// Streams raw CoreLocation fixes without any road snapping or smoothing beyond what iOS itself does.
@MainActor
@Observable
final class LocationModel: NSObject, CLLocationManagerDelegate {
    enum Mode: String {
        case ground, air

        /// `.otherNavigation` (trains, boats) and `.airborne` both tell iOS not to assume
        /// you're on a road. Never use `.automotiveNavigation` here: it can snap to roads.
        var configuration: CLLocationUpdate.LiveConfiguration {
            self == .air ? .airborne : .otherNavigation
        }
    }

    private(set) var location: CLLocation?
    /// Speed computed from the last two fixes, used when the GNSS (Doppler) speed is invalid.
    private(set) var derivedSpeed: Double?
    private(set) var isStationary = false
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    var mode: Mode = .ground {
        didSet { if oldValue != mode { start() } }
    }

    private let manager = CLLocationManager()
    private var task: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        authorization = manager.authorizationStatus
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        task?.cancel()
        let configuration = mode.configuration
        task = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(configuration) {
                    guard let self else { return }
                    self.isStationary = update.isStationary
                    if let location = update.location {
                        self.ingest(location)
                    }
                }
            } catch {
                // Stream ended (e.g. task cancelled on mode switch); nothing to do.
            }
        }
    }

    private func ingest(_ new: CLLocation) {
        if let previous = location, new.timestamp > previous.timestamp {
            let dt = new.timestamp.timeIntervalSince(previous.timestamp)
            derivedSpeed = new.distance(from: previous) / dt
        }
        location = new
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}
