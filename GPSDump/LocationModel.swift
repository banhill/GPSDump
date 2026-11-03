import CoreLocation
import Observation

/// A speed value the app is willing to show.
struct SpeedReading {
    enum Source { case doppler, derived }

    let metersPerSecond: Double
    /// ± uncertainty in m/s.
    let accuracy: Double
    let source: Source
}

/// Streams raw CoreLocation fixes without any road snapping or smoothing beyond what iOS itself does.
@MainActor
@Observable
final class LocationModel: NSObject, CLLocationManagerDelegate {
    /// About twice an airliner's cruising speed (1,800 km/h). Anything faster is a bad fix.
    static let maxPlausibleSpeed = 500.0
    /// Reject Doppler speeds whose own reported uncertainty exceeds this (36 km/h).
    static let maxDopplerAccuracy = 10.0
    /// Fixes worse than this (typically Wi-Fi or cell-based positions) are not used to derive speed.
    static let maxFixAccuracyForDerivedSpeed = 100.0

    private(set) var location: CLLocation?
    /// `nil` while there is no trustworthy speed; the UI shows "—" then.
    private(set) var speed: SpeedReading?
    private(set) var isStationary = false
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var task: Task<Void, Never>?
    /// Earlier good fix that derived speed is measured from.
    private var anchor: CLLocation?
    private var lastDerived: (reading: SpeedReading, at: Date)?

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
        // `.airborne` is the least constrained hint: no road snapping, no assumption that
        // altitude stays put. It suits trains as well as planes. Never use
        // `.automotiveNavigation` here: it can snap to roads.
        task = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.airborne) {
                    guard let self else { return }
                    self.isStationary = update.isStationary
                    if let location = update.location {
                        self.ingest(location)
                    }
                }
            } catch {
                // Stream ended; nothing to do.
            }
        }
    }

    func ingest(_ new: CLLocation) {
        location = new
        let derived = deriveSpeed(to: new)

        if new.speed >= 0, new.speedAccuracy >= 0,
           new.speedAccuracy <= Self.maxDopplerAccuracy,
           new.speed <= Self.maxPlausibleSpeed {
            speed = SpeedReading(metersPerSecond: new.speed, accuracy: new.speedAccuracy, source: .doppler)
        } else if let derived {
            speed = derived
        } else if let lastDerived, new.timestamp.timeIntervalSince(lastDerived.at) < 5 {
            speed = lastDerived.reading // still waiting for enough distance; keep the recent value
        } else {
            speed = nil
        }
    }

    /// Speed from the distance between an earlier good fix and this one. Only accepted once the
    /// distance is large enough that the fixes' position errors don't dominate the result.
    private func deriveSpeed(to new: CLLocation) -> SpeedReading? {
        guard new.horizontalAccuracy >= 0,
              new.horizontalAccuracy <= Self.maxFixAccuracyForDerivedSpeed else { return nil }
        guard let anchor, new.timestamp.timeIntervalSince(anchor.timestamp) <= 30 else {
            anchor = new
            return nil
        }
        let dt = new.timestamp.timeIntervalSince(anchor.timestamp)
        guard dt >= 1 else { return nil }

        let value = new.distance(from: anchor) / dt
        let uncertainty = (new.horizontalAccuracy + anchor.horizontalAccuracy) / dt
        // Wait for more distance until the error is within 5 m/s (18 km/h) or 5 %.
        guard uncertainty <= max(5, 0.05 * value) else { return nil }

        self.anchor = new
        guard value <= Self.maxPlausibleSpeed else { return nil }
        let reading = SpeedReading(metersPerSecond: value, accuracy: uncertainty, source: .derived)
        lastDerived = (reading, new.timestamp)
        return reading
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}
