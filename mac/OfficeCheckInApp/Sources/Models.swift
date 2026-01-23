import Foundation

enum DayType: String, Codable, CaseIterable, Identifiable {
    case inOffice
    case pto
    case sick
    case exempt
    case publicHoliday

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inOffice: return "In Office"
        case .pto: return "PTO"
        case .sick: return "Sick"
        case .exempt: return "Exempt"
        case .publicHoliday: return "Public Holiday"
        }
    }
}

struct DayLog: Codable {
    /// Keys are YYYY-MM-DD in the user's current calendar/timezone (start-of-day).
    var entries: [String: DayType] = [:]
    /// Date keys that were auto-marked via geofencing
    var geofencedDates: Set<String> = []
    
    // Custom decoder to handle old data without geofencedDates
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([String: DayType].self, forKey: .entries) ?? [:]
        geofencedDates = try container.decodeIfPresent(Set<String>.self, forKey: .geofencedDates) ?? []
    }
    
    init() {}
}

struct OfficeLocation: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double = 250
    var isEnabled: Bool = true
}

struct OfficeConfig: Codable {
    var targetPct: Double = 50
    /// Swift weekday ints: Sun=1 ... Sat=7. Default prefers Tue/Wed/Thu then Mon/Fri.
    var preferredWeekdays: [Int] = [3, 4, 5, 2, 6]

    // Multiple office locations for geofencing
    var offices: [OfficeLocation] = []
    
    // Launch at login
    var launchAtLogin: Bool = false
    
    // CodingKeys includes old fields for migration
    private enum CodingKeys: String, CodingKey {
        case targetPct
        case preferredWeekdays
        case offices
        case launchAtLogin
        // Old single-office fields for migration
        case officeName
        case officeLatitude
        case officeLongitude
        case officeRadiusMeters
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetPct = try container.decodeIfPresent(Double.self, forKey: .targetPct) ?? 50
        preferredWeekdays = try container.decodeIfPresent([Int].self, forKey: .preferredWeekdays) ?? [3, 4, 5, 2, 6]
        offices = try container.decodeIfPresent([OfficeLocation].self, forKey: .offices) ?? []
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        
        // Migrate old single-office format
        if offices.isEmpty {
            let oldName = try container.decodeIfPresent(String.self, forKey: .officeName)
            let oldLat = try container.decodeIfPresent(Double.self, forKey: .officeLatitude)
            let oldLon = try container.decodeIfPresent(Double.self, forKey: .officeLongitude)
            let oldRadius = try container.decodeIfPresent(Double.self, forKey: .officeRadiusMeters) ?? 250
            
            if let name = oldName, let lat = oldLat, let lon = oldLon {
                offices = [OfficeLocation(name: name, latitude: lat, longitude: lon, radiusMeters: oldRadius)]
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetPct, forKey: .targetPct)
        try container.encode(preferredWeekdays, forKey: .preferredWeekdays)
        try container.encode(offices, forKey: .offices)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        // Don't encode old single-office fields
    }
}

final class OfficeStore: ObservableObject {
    @Published var config = OfficeConfig()
    @Published var log = DayLog()

    private let defaultsKey = "office_checkin_state_v1"
    private var lastKnownState: PersistedState?

    init() {
        load()
    }

    func set(_ type: DayType?, for date: Date, calendar: Calendar = .current, geofenced: Bool = false) {
        let key = calendar.dayKey(for: date)
        if let type {
            log.entries[key] = type
            if geofenced && type == .inOffice {
                log.geofencedDates.insert(key)
            } else {
                // If manually set, remove from geofenced
                log.geofencedDates.remove(key)
            }
        } else {
            log.entries.removeValue(forKey: key)
            log.geofencedDates.remove(key)
        }
        save()
    }
    
    func isGeofenced(_ date: Date, calendar: Calendar = .current) -> Bool {
        let key = calendar.dayKey(for: date)
        return log.geofencedDates.contains(key)
    }

    func save() {
        let state = PersistedState(config: config, log: log, lastUpdated: Date())
        saveToDefaults(state)
        lastKnownState = state
    }

    private func load() {
        // Load from local UserDefaults only (iCloud sync removed)
        guard let localState = loadFromDefaults() else { return }
        config = localState.config
        log = localState.log
        lastKnownState = localState
    }

    private struct PersistedState: Codable {
        var config: OfficeConfig
        var log: DayLog
        var lastUpdated: Date
        
        init(config: OfficeConfig, log: DayLog, lastUpdated: Date = Date()) {
            self.config = config
            self.log = log
            self.lastUpdated = lastUpdated
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            config = try container.decode(OfficeConfig.self, forKey: .config)
            log = try container.decode(DayLog.self, forKey: .log)
            lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        }
    }

    private func saveToDefaults(_ state: PersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func loadFromDefaults() -> PersistedState? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }
}

extension Calendar {
    func dayKey(for date: Date) -> String {
        let d = startOfDay(for: date)
        let comps = dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").map(String.init)
        guard parts.count == 3 else { return nil }
        guard let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return date(from: DateComponents(year: y, month: m, day: d))
    }
}

