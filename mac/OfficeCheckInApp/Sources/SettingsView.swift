import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var store: OfficeStore
    @EnvironmentObject private var location: LocationMonitor

    @State private var targetPctText: String = ""
    @State private var radiusText: String = ""
    @State private var officeName: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var coordinatesText: String = ""
    @State private var coordinatesError: String? = nil

    private let labelWidth: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // General
            GroupBox("General") {
                HStack {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                    Spacer()
                }
                .padding(12)
            }
            
            // Goal
            GroupBox("Goal") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Target attendance")
                            .frame(width: labelWidth, alignment: .leading)
                        TextField("50", text: $targetPctText)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commitTarget)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                    Text("Eligible working days exclude PTO, Sick, Exempt, and Public Holidays.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // Office Geofence
            GroupBox("Office Geofence") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Office name")
                            .frame(width: labelWidth, alignment: .leading)
                        TextField("Office", text: $officeName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commitOfficeName)
                    }

                    HStack {
                        Text("Radius")
                            .frame(width: labelWidth, alignment: .leading)
                        TextField("250", text: $radiusText)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(commitRadius)
                        Text("meters")
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text("Coordinates")
                                .frame(width: labelWidth, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("Paste Google Maps URL or lat, lon", text: $coordinatesText)
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit(commitCoordinates)
                                    Button("Set") {
                                        commitCoordinates()
                                    }
                                    .disabled(coordinatesText.isEmpty)
                                }
                                if let current = currentCoordinatesText {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        Text(current)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                        Text("No coordinates set")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let error = coordinatesError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Text("Location permission")
                            .frame(width: labelWidth, alignment: .leading)
                        Text(location.authorizationStatusText)
                            .foregroundStyle(location.authorizationStatus == .authorizedAlways ? .green : .secondary)
                        Spacer()
                        Button("Request") { location.requestPermission() }
                            .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        Button("Use Current Location") {
                            commitOfficeName()
                            location.setOfficeToCurrentLocation(name: store.config.officeName)
                        }
                        Button("Start Monitoring") { 
                            location.startMonitoringIfConfigured() 
                        }
                        Spacer()
                        if location.isMonitoring {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("Active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let msg = location.lastEvent {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Text("Geofencing auto-marks today as 'In Office' when you enter the region. Skips weekends and stops after first detection each day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }

            // Data
            GroupBox("Data") {
                HStack {
                    Button("Reset All Data", role: .destructive) {
                        store.log.entries.removeAll()
                        store.save()
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear {
            targetPctText = String(Int(store.config.targetPct))
            radiusText = String(Int(store.config.officeRadiusMeters))
            officeName = store.config.officeName
            launchAtLogin = store.config.launchAtLogin
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        store.config.launchAtLogin = enabled
        store.save()
        
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    private func commitTarget() {
        let trimmed = targetPctText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else { return }
        store.config.targetPct = max(0, min(100, value))
        store.save()
        targetPctText = String(Int(store.config.targetPct))
    }

    private func commitRadius() {
        let trimmed = radiusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else { return }
        store.config.officeRadiusMeters = max(50, min(5000, value))
        store.save()
        radiusText = String(Int(store.config.officeRadiusMeters))
    }

    private func commitOfficeName() {
        let trimmed = officeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.config.officeName = trimmed
            store.save()
        }
        officeName = store.config.officeName
    }
    
    private func commitCoordinates() {
        coordinatesError = nil
        let trimmed = coordinatesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if location.parseAndSetCoordinates(trimmed) {
            coordinatesText = ""
            location.startMonitoringIfConfigured()
        } else {
            coordinatesError = "Could not parse coordinates"
        }
    }
    
    private var currentCoordinatesText: String? {
        guard let lat = store.config.officeLatitude,
              let lon = store.config.officeLongitude else { return nil }
        return String(format: "%.5f, %.5f", lat, lon)
    }
}

private extension LocationMonitor {
    var authorizationStatusText: String {
        switch authorizationStatus {
        case .notDetermined: return "Not determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
}

