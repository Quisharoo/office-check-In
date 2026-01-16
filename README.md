## Office Check‑In (macOS menubar app)

Track office attendance, PTO, sick days, exemptions, and public holidays with a lightweight macOS menubar app. Calculates your flex % for the month and/or fiscal quarter and suggests remaining in‑office days to hit target.

### Requirements
- macOS 14+

### Install
**GitHub Releases (public):**
1. Download the latest release from GitHub: https://github.com/Quisharoo/office-check-In/releases/latest
2. Unzip and move `OfficeCheckIn.app` to `/Applications`.

**Homebrew (public, via tap — planned):**
```bash
brew install --cask quisharoo/tap/office-check-in
```

**Homebrew (local cask):**
```bash
./Scripts/package_app.sh
brew install --cask ./Casks/office-check-in-local.rb
```

**From source:**
Open `mac/OfficeCheckInApp/Package.swift` in Xcode and click **Run**.

### Notes
- Geofencing is optional. Manual marking works without any location permissions.
- If you add CoreLocation to a packaged app target, you’ll need location usage strings in Info.plist.
