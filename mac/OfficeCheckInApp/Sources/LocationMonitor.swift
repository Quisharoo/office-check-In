import Foundation
import CoreLocation

final class LocationMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastEvent: String? = nil

    private let manager = CLLocationManager()
    private weak var store: OfficeStore?
    private var didBind = false

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func bind(store: OfficeStore) {
        guard !didBind else { return }
        didBind = true
        self.store = store
        // If config already has a region, try to start monitoring.
        startMonitoringIfConfigured()
    }

    func requestPermission() {
        // On macOS, CoreLocation supports `.authorized` / `.authorizedAlways` (no `authorizedWhenInUse`).
        // Region monitoring generally expects "Always" style authorization.
        manager.requestAlwaysAuthorization()
    }

    func setOfficeToCurrentLocation(name: String = "Office") {
        manager.requestLocation()
        // We'll capture location in didUpdateLocations and then set config.
        // Name is applied when saving.
        pendingOfficeName = name
    }

    private var pendingOfficeName: String? = nil

    func startMonitoringIfConfigured() {
        guard let store else { return }
        guard let lat = store.config.officeLatitude,
              let lon = store.config.officeLongitude else {
            return
        }
        let radius = max(50, min(5000, store.config.officeRadiusMeters))
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = CLCircularRegion(center: center, radius: radius, identifier: "office")
        region.notifyOnEntry = true
        region.notifyOnExit = true

        // Replace any existing.
        for r in manager.monitoredRegions {
            manager.stopMonitoring(for: r)
        }
        manager.startMonitoring(for: region)
        lastEvent = "Monitoring \(store.config.officeName) (\(Int(radius))m)"
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorized {
            startMonitoringIfConfigured()
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        lastEvent = "Started monitoring region"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastEvent = "Location error: \(error.localizedDescription)"
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        lastEvent = "Entered office region"
        markTodayInOffice()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        lastEvent = "Exited office region"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let store else { return }
        guard let loc = locations.last else { return }
        let name = pendingOfficeName ?? store.config.officeName
        pendingOfficeName = nil

        store.config.officeName = name
        store.config.officeLatitude = loc.coordinate.latitude
        store.config.officeLongitude = loc.coordinate.longitude
        store.save()
        startMonitoringIfConfigured()
        lastEvent = "Set office to current location"
    }

    private func markTodayInOffice() {
        guard let store else { return }
        // Only auto-mark if today isn't already a day-off label.
        let cal = Calendar.current
        let key = cal.dayKey(for: Date())
        switch store.log.entries[key] {
        case .pto, .sick, .exempt, .publicHoliday:
            return
        default:
            store.set(.inOffice, for: Date(), calendar: cal)
        }
    }
}

