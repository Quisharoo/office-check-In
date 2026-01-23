# Office Check‑In

A macOS menubar app for tracking office attendance. Shows your flex percentage for the month/quarter and suggests days to hit your target.

## Install

### Homebrew

```bash
brew tap quisharoo/tap
brew install --cask office-check-in
xattr -cr /Applications/OfficeCheckIn.app
open /Applications/OfficeCheckIn.app
```

**Upgrade:**

```bash
brew upgrade --cask office-check-in
xattr -cr /Applications/OfficeCheckIn.app
```

> Note: `xattr` is needed because the app is not notarized.

### Manual

Download from [Releases](https://github.com/Quisharoo/office-check-In/releases/latest), unzip, move to `/Applications`, then run the `xattr` command above.

## Development

### Build from source

```bash
git clone https://github.com/Quisharoo/office-check-In.git
cd office-check-In
swift build -c release --package-path mac/OfficeCheckInApp
```

### Run locally (development)

```bash
# Build and package
./Scripts/package_app.sh

# Remove quarantine and run
xattr -cr dist/OfficeCheckIn.app
open dist/OfficeCheckIn.app
```

Or install to Applications:

```bash
./Scripts/package_app.sh
cp -r dist/OfficeCheckIn.app /Applications/
xattr -cr /Applications/OfficeCheckIn.app
open /Applications/OfficeCheckIn.app
```

## Troubleshooting

**App won't open / "move to bin" error:**
```bash
xattr -cr /Applications/OfficeCheckIn.app
open /Applications/OfficeCheckIn.app
```

**App disappears from menu bar:**
```bash
killall cfprefsd; open /Applications/OfficeCheckIn.app
```

---

![Office Check-In Screenshot](screenshot.png)

