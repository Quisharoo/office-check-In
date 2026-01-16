import Foundation
import CoreLocation
import UserNotifications

final class LocationMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastEvent: String? = nil
    @Published private(set) var isMonitoring: Bool = false

    private let manager = CLLocationManager()
    private weak var store: OfficeStore?
    private var didBind = false
    private var markedTodayKey: String? = nil  // Track if we already marked today

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
    
    /// Set office coordinates manually (e.g., from Google Maps)
    func setOfficeCoordinates(latitude: Double, longitude: Double) {
        guard let store else { return }
        store.config.officeLatitude = latitude
        store.config.officeLongitude = longitude
        store.save()
        startMonitoringIfConfigured()
        lastEvent = "Set office to \(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))"
    }
    
    /// Parse coordinates from various formats (Google Maps URL, "lat, lon", etc.)
    func parseAndSetCoordinates(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try Google Maps URL format: .../@51.5074,-0.1278,... or ...!3d51.5074!4d-0.1278...
        if let match = trimmed.range(of: #"@(-?\d+\.?\d*),(-?\d+\.?\d*)"#, options: .regularExpression) {
            let coords = String(trimmed[match]).dropFirst() // remove @
            let parts = coords.split(separator: ",")
            if parts.count >= 2,
               let lat = Double(parts[0]),
               let lon = Double(parts[1]) {
                setOfficeCoordinates(latitude: lat, longitude: lon)
                return true
            }
        }
        
        // Try !3d...!4d... format
        if let latMatch = trimmed.range(of: #"!3d(-?\d+\.?\d*)"#, options: .regularExpression),
           let lonMatch = trimmed.range(of: #"!4d(-?\d+\.?\d*)"#, options: .regularExpression) {
            let latStr = String(trimmed[latMatch]).dropFirst(3)
            let lonStr = String(trimmed[lonMatch]).dropFirst(3)
            if let lat = Double(latStr), let lon = Double(lonStr) {
                setOfficeCoordinates(latitude: lat, longitude: lon)
                return true
            }
        }
        
        // Try simple "lat, lon" or "lat lon" format
        let simple = trimmed.replacingOccurrences(of: ",", with: " ")
        let parts = simple.split(separator: " ").compactMap { Double($0) }
        if parts.count >= 2 {
            setOfficeCoordinates(latitude: parts[0], longitude: parts[1])
            return true
        }
        
        return false
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
            lastEvent = "No office location configured"
            return
        }
        
        let cal = Calendar.current
        let today = Date()
        let todayKey = cal.dayKey(for: today)
        
        // Don't monitor on weekends
        let weekday = cal.component(.weekday, from: today)
        if weekday == 1 || weekday == 7 { // Sunday = 1, Saturday = 7
            stopMonitoring()
            lastEvent = "Weekend — monitoring paused"
            return
        }
        
        // Don't monitor if we already marked today as in-office
        if store.log.entries[todayKey] == .inOffice {
            stopMonitoring()
            lastEvent = "Already checked in today"
            return
        }
        
        let radius = max(50, min(5000, store.config.officeRadiusMeters))
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = CLCircularRegion(center: center, radius: radius, identifier: "office")
        region.notifyOnEntry = true
        region.notifyOnExit = false // We only care about entry

        // Replace any existing.
        for r in manager.monitoredRegions {
            manager.stopMonitoring(for: r)
        }
        manager.startMonitoring(for: region)
        isMonitoring = true
        lastEvent = "Monitoring \(store.config.officeName) (\(Int(radius))m)"
    }
    
    func stopMonitoring() {
        for r in manager.monitoredRegions {
            manager.stopMonitoring(for: r)
        }
        isMonitoring = false
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
        let cal = Calendar.current
        let key = cal.dayKey(for: Date())
        
        // Only auto-mark if today isn't already marked
        switch store.log.entries[key] {
        case .pto, .sick, .exempt, .publicHoliday, .inOffice:
            return
        default:
            store.set(.inOffice, for: Date(), calendar: cal)
            markedTodayKey = key
            // Stop monitoring for the rest of the day
            stopMonitoring()
            lastEvent = "✓ Checked in at \(store.config.officeName)"
            sendCheckedInNotification(officeName: store.config.officeName)
        }
    }
    
    private func sendCheckedInNotification(officeName: String) {
        let center = UNUserNotificationCenter.current()
        
        // Request permission if needed
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Office Check-In"
            content.body = "Marked as in office at \(officeName). Have a productive day!"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "office-checkin-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil // Deliver immediately
            )
            
            center.add(request)
        }
    }
}

