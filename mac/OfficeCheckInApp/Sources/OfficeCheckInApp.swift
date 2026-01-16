import SwiftUI

@main
struct OfficeCheckInApp: App {
    @StateObject private var store = OfficeStore()
    @StateObject private var location = LocationMonitor()

    var body: some Scene {
        MenuBarExtra {
            StatusCardView()
                .environmentObject(store)
                .environmentObject(location)
                .frame(width: 520)
                .padding(16)
                .onAppear {
                    location.bind(store: store)
                }
        } label: {
            Label("Office Check-In", systemImage: "building.2")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(location)
                .frame(width: 560, height: 520)
                .padding()
        }
    }
}

