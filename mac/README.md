## Office Check-In (macOS menubar app) — local testing

This repo originally contained a Chrome extension prototype. If you want to **stop relying on Chrome**, use the macOS menubar app sources in `mac/`.

### Requirements
- macOS 13+ (for `MenuBarExtra`) recommended
- Xcode 15+ recommended

### Quick start (Xcode)
1. Open Xcode → **File → New → Project…**
2. Choose **macOS → App**
3. Product Name: **OfficeCheckIn** (or whatever you prefer)
4. Interface: **SwiftUI**, Language: **Swift**
5. Create the project anywhere (for now).
6. Copy the contents of this repo’s `mac/OfficeCheckIn/` folder into your Xcode project’s source folder.
7. Replace the generated `YourAppApp.swift` with `OfficeCheckInApp.swift` (or set the app entry point accordingly).

### Make it a true menubar app (no Dock icon)
In your Xcode project:
- Add an Info.plist key: **Application is agent (UIElement)** = `YES`

### Location permission (later)
When we wire CoreLocation, you’ll need:
- `NSLocationWhenInUseUsageDescription` in Info.plist

### Notes
- The current Swift app is a **starter**: it includes the core % calculation + a “recommended office days” projection algorithm.
- Next step will be swapping the placeholder data store for a real local store + CoreLocation geofencing.

