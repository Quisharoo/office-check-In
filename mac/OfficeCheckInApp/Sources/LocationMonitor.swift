import Foundation
import CoreLocation
import UserNotifications
import AppKit

final class LocationMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastEvent: String? = nil
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var monitoredOfficeCount: Int = 0

    private let manager = CLLocationManager()
    private weak var store: OfficeStore?
    private var didBind = false
    private var markedTodayKey: String? = nil
    private var pendingOfficeForCurrentLocation: OfficeLocation? = nil

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        
        // Listen for wake from sleep to auto-check location
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func systemDidWake() {
        // When Mac wakes, do an immediate location check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkLocationNow()
        }
    }

    func bind(store: OfficeStore) {
        guard !didBind else { return }
        didBind = true
        self.store = store
        startMonitoringIfConfigured()
        
        // Auto-check location on app launch (after a short delay for permissions)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkLocationNow()
        }
    }

    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }
    
    // MARK: - Office Management
    
    func addOffice(_ office: OfficeLocation) {
        guard let store else { return }
        store.config.offices.append(office)
        store.save()
        startMonitoringIfConfigured()
    }
    
    func updateOffice(_ office: OfficeLocation) {
        guard let store else { return }
        if let index = store.config.offices.firstIndex(where: { $0.id == office.id }) {
            store.config.offices[index] = office
            store.save()
            startMonitoringIfConfigured()
        }
    }
    
    func removeOffice(id: UUID) {
        guard let store else { return }
        store.config.offices.removeAll { $0.id == id }
        store.save()
        startMonitoringIfConfigured()
    }
    
    func setCurrentLocationForOffice(_ office: OfficeLocation) {
        pendingOfficeForCurrentLocation = office
        manager.requestLocation()
    }
    
    // Pre-compiled regex patterns for performance
    private static let googleMapsRegex = /@(-?\d+\.?\d*),(-?\d+\.?\d*)/
    private static let latRegex = /!3d(-?\d+\.?\d*)/
    private static let lonRegex = /!4d(-?\d+\.?\d*)/

    /// Parse coordinates from various formats (Google Maps URL, "lat, lon", etc.)
    func parseCoordinates(_ input: String) -> (latitude: Double, longitude: Double)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try Google Maps URL format: .../@51.5074,-0.1278,...
        if let match = trimmed.firstMatch(of: Self.googleMapsRegex) {
            let (_, latStr, lonStr) = match.output
            if let lat = Double(latStr), let lon = Double(lonStr) {
                return (lat, lon)
            }
        }
        
        // Try !3d...!4d... format
        if let latMatch = trimmed.firstMatch(of: Self.latRegex),
           let lonMatch = trimmed.firstMatch(of: Self.lonRegex) {
            let (_, latStr) = latMatch.output
            let (_, lonStr) = lonMatch.output
            if let lat = Double(latStr), let lon = Double(lonStr) {
                return (lat, lon)
            }
        }
        
        // Try simple "lat, lon" or "lat lon" format
        let simple = trimmed.replacingOccurrences(of: ",", with: " ")
        let parts = simple.split(separator: " ").compactMap { Double($0) }
        if parts.count >= 2 {
            return (parts[0], parts[1])
        }
        
        return nil
    }

    // MARK: - Monitoring
    
    func startMonitoringIfConfigured() {
        guard let store else { return }
        
        let enabledOffices = store.config.offices.filter { $0.isEnabled }
        
        guard !enabledOffices.isEmpty else {
            stopMonitoring()
            lastEvent = "No offices configured"
            return
        }
        
        let cal = Calendar.current
        let today = Date()
        let todayKey = cal.dayKey(for: today)
        
        // Don't monitor on weekends
        let weekday = cal.component(.weekday, from: today)
        if weekday == 1 || weekday == 7 {
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
        
        // Stop existing monitoring
        for r in manager.monitoredRegions {
            manager.stopMonitoring(for: r)
        }
        
        // Start monitoring all enabled offices (up to 20, iOS/macOS limit)
        for office in enabledOffices.prefix(20) {
            let center = CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude)
            let radius = max(50, min(5000, office.radiusMeters))
            let region = CLCircularRegion(center: center, radius: radius, identifier: office.id.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
        
        isMonitoring = true
        monitoredOfficeCount = min(enabledOffices.count, 20)
        
        if enabledOffices.count == 1 {
            lastEvent = "Monitoring \(enabledOffices[0].name)"
        } else {
            lastEvent = "Monitoring \(monitoredOfficeCount) offices"
        }
    }
    
    /// Check current location immediately against all enabled offices
    func checkLocationNow() {
        guard let store else { return }
        let enabledOffices = store.config.offices.filter { $0.isEnabled }
        guard !enabledOffices.isEmpty else {
            lastEvent = "No offices configured"
            return
        }
        
        // Don't check on weekends
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        if weekday == 1 || weekday == 7 {
            lastEvent = "Weekend — no check needed"
            return
        }
        
        // Don't check if already marked today
        let todayKey = cal.dayKey(for: Date())
        if store.log.entries[todayKey] == .inOffice {
            lastEvent = "Already checked in today"
            return
        }
        
        // Store offices to check against when location arrives
        pendingLocationCheck = enabledOffices
        manager.requestLocation()
        lastEvent = "Checking location..."
    }
    
    private var pendingLocationCheck: [OfficeLocation]? = nil
    
    func stopMonitoring() {
        for r in manager.monitoredRegions {
            manager.stopMonitoring(for: r)
        }
        isMonitoring = false
        monitoredOfficeCount = 0
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorized {
            startMonitoringIfConfigured()
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        // Silent - we log the aggregate in startMonitoringIfConfigured
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        pendingLocationCheck = nil  // Clear pending check on error
        pendingOfficeForCurrentLocation = nil
        lastEvent = "Location error: \(error.localizedDescription)"
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let store else { return }
        let officeName = store.config.offices.first { $0.id.uuidString == region.identifier }?.name ?? "Office"
        markTodayInOffice(officeName: officeName)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // We don't need to do anything on exit
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let store else { return }
        guard let loc = locations.last else { return }
        
        // Handle "Use Current Location" for setting office coordinates
        if var office = pendingOfficeForCurrentLocation {
            office.latitude = loc.coordinate.latitude
            office.longitude = loc.coordinate.longitude
            
            if let index = store.config.offices.firstIndex(where: { $0.id == office.id }) {
                store.config.offices[index] = office
            } else {
                store.config.offices.append(office)
            }
            store.save()
            pendingOfficeForCurrentLocation = nil
            startMonitoringIfConfigured()
            lastEvent = "Set \(office.name) to current location"
            return
        }
        
        // Handle "Check Now" - see if we're inside any enabled office
        if let offices = pendingLocationCheck {
            pendingLocationCheck = nil
            
            for office in offices {
                let officeLocation = CLLocation(latitude: office.latitude, longitude: office.longitude)
                let distance = loc.distance(from: officeLocation)
                
                if distance <= office.radiusMeters {
                    markTodayInOffice(officeName: office.name)
                    return
                }
            }
            
            lastEvent = "Not at any office location"
        }
    }

    private func markTodayInOffice(officeName: String) {
        guard let store else { return }
        let cal = Calendar.current
        let key = cal.dayKey(for: Date())
        
        switch store.log.entries[key] {
        case .pto, .sick, .exempt, .publicHoliday, .inOffice:
            return
        default:
            store.set(.inOffice, for: Date(), calendar: cal, geofenced: true)
            markedTodayKey = key
            stopMonitoring()
            lastEvent = "✓ Checked in at \(officeName)"
            sendCheckedInNotification(officeName: officeName)
        }
    }
    
    private func sendCheckedInNotification(officeName: String) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Office Check-In"
            content.body = "Marked as in office at \(officeName). Have a productive day!"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "office-checkin-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            
            center.add(request)
        }
    }
}

