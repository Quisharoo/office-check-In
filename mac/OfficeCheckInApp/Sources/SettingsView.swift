import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var store: OfficeStore
    @EnvironmentObject private var location: LocationMonitor

    @State private var targetPctText: String = ""
    @State private var radiusText: String = ""
    @State private var officeName: String = ""
    @State private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
            
            Section("Goal") {
                HStack {
                    Text("Target attendance")
                    Spacer()
                    TextField("", text: $targetPctText)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .onSubmit(commitTarget)
                    Text("%")
                        .foregroundStyle(.secondary)
                }
                Text("Eligible working days exclude PTO/Sick/Exempt/Public Holiday.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Office (geofence)") {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Office", text: $officeName)
                        .frame(width: 240)
                        .onSubmit(commitOfficeName)
                }

                HStack {
                    Text("Radius")
                    Spacer()
                    TextField("250", text: $radiusText)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                        .onSubmit(commitRadius)
                    Text("m")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Location permission")
                    Spacer()
                    Text(location.authorizationStatusText)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button("Request Permission") { location.requestPermission() }
                    Button("Set Office to Current Location") {
                        commitOfficeName()
                        location.setOfficeToCurrentLocation(name: store.config.officeName)
                    }
                    Button("Start Monitoring") { location.startMonitoringIfConfigured() }
                }
                .controlSize(.small)

                if let msg = location.lastEvent {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Text("Geofencing auto-marks today as 'In Office' when you enter the region. Requires location permission and a configured office.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button("Reset local data") {
                    store.log.entries.removeAll()
                    store.save()
                }
            }
        }
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

