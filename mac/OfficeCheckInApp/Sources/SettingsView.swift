import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var store: OfficeStore
    @EnvironmentObject private var location: LocationMonitor

    @State private var targetPctText: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var showingAddOffice: Bool = false
    @State private var editingOffice: OfficeLocation? = nil

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
                        Spacer()
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
                .padding(12)
            }

            // Office Locations
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Text("Office Locations")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddOffice = true
                        } label: {
                            Label("Add Office", systemImage: "plus")
                        }
                    }
                    
                    if store.config.offices.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "building.2")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No offices configured")
                                    .foregroundStyle(.secondary)
                                Text("Add an office to enable geofencing")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(store.config.offices) { office in
                            OfficeRowView(
                                office: office,
                                onEdit: { editingOffice = office },
                                onDelete: { location.removeOffice(id: office.id) },
                                onToggle: { enabled in
                                    var updated = office
                                    updated.isEnabled = enabled
                                    location.updateOffice(updated)
                                }
                            )
                            if office.id != store.config.offices.last?.id {
                                Divider()
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Location permission & status
                    HStack {
                        Text("Location permission:")
                            .foregroundStyle(.secondary)
                        Text(location.authorizationStatusText)
                            .foregroundStyle(location.authorizationStatus == .authorizedAlways ? .green : .secondary)
                        Spacer()
                        Button("Request") { location.requestPermission() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    
                    HStack {
                        Button("Start Monitoring") { 
                            location.startMonitoringIfConfigured() 
                        }
                        .disabled(store.config.offices.isEmpty)
                        
                        Button("Check Now") {
                            location.checkLocationNow()
                        }
                        .disabled(store.config.offices.isEmpty)
                        .help("Check if you're currently at an office")
                        
                        Spacer()
                        
                        if location.isMonitoring {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("Monitoring \(location.monitoredOfficeCount) office\(location.monitoredOfficeCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let msg = location.lastEvent {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Geofencing auto-marks today as 'In Office' when you enter any enabled office region. Skips weekends and stops after first detection each day.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
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
                .padding(12)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 600)
        .onAppear {
            targetPctText = String(Int(store.config.targetPct))
            launchAtLogin = store.config.launchAtLogin
        }
        .sheet(isPresented: $showingAddOffice) {
            OfficeEditorView(
                office: nil,
                onSave: { office in
                    location.addOffice(office)
                    showingAddOffice = false
                },
                onCancel: { showingAddOffice = false }
            )
            .environmentObject(location)
        }
        .sheet(item: $editingOffice) { office in
            OfficeEditorView(
                office: office,
                onSave: { updated in
                    location.updateOffice(updated)
                    editingOffice = nil
                },
                onCancel: { editingOffice = nil }
            )
            .environmentObject(location)
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
}

// MARK: - Office Row

struct OfficeRowView: View {
    let office: OfficeLocation
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { office.isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(office.name)
                    .fontWeight(.medium)
                    .foregroundStyle(office.isEnabled ? .primary : .secondary)
                Text("\(String(format: "%.4f", office.latitude)), \(String(format: "%.4f", office.longitude)) · \(Int(office.radiusMeters))m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Office Editor

struct OfficeEditorView: View {
    @EnvironmentObject private var location: LocationMonitor
    
    let office: OfficeLocation?
    let onSave: (OfficeLocation) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var coordinatesText: String = ""
    @State private var radiusText: String = "250"
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var parseError: String? = nil
    
    private var isEditing: Bool { office != nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isEditing ? "Edit Office" : "Add Office")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Name")
                        .frame(width: 100, alignment: .leading)
                    TextField("Office name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Radius")
                        .frame(width: 100, alignment: .leading)
                    TextField("250", text: $radiusText)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("meters")
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text("Coordinates")
                            .frame(width: 100, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Paste Google Maps URL or lat, lon", text: $coordinatesText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: coordinatesText) { _, newValue in
                                    parseCoordinatesInput(newValue)
                                }
                            
                            if let lat = latitude, let lon = longitude {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("\(String(format: "%.5f", lat)), \(String(format: "%.5f", lon))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = parseError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            
                            Button("Use Current Location") {
                                // This will be handled via location callback
                                let tempOffice = OfficeLocation(
                                    id: office?.id ?? UUID(),
                                    name: name.isEmpty ? "Office" : name,
                                    latitude: 0,
                                    longitude: 0,
                                    radiusMeters: Double(radiusText) ?? 250
                                )
                                location.setCurrentLocationForOffice(tempOffice)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Add") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 400, height: 320)
        .onAppear {
            if let office = office {
                name = office.name
                latitude = office.latitude
                longitude = office.longitude
                radiusText = String(Int(office.radiusMeters))
                coordinatesText = "\(office.latitude), \(office.longitude)"
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        latitude != nil &&
        longitude != nil
    }
    
    private func parseCoordinatesInput(_ input: String) {
        parseError = nil
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            latitude = nil
            longitude = nil
            return
        }
        
        if let coords = location.parseCoordinates(trimmed) {
            latitude = coords.latitude
            longitude = coords.longitude
        } else {
            parseError = "Could not parse coordinates"
        }
    }
    
    private func save() {
        guard let lat = latitude, let lon = longitude else { return }
        
        let newOffice = OfficeLocation(
            id: office?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            latitude: lat,
            longitude: lon,
            radiusMeters: Double(radiusText) ?? 250,
            isEnabled: office?.isEnabled ?? true
        )
        
        onSave(newOffice)
    }
}

// MARK: - Extensions

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
