# Office Check‑In

![Office Check-In Screenshot](screenshot.png)

A macOS menubar app for tracking office attendance. Shows your office attendance percentage for the month/quarter and suggests days to hit your target.

## Install

### Homebrew

```bash
# Copy/paste this ONE command (install/upgrade/clean/launch; no sudo needed)
brew untap quisharoo/tap 2>/dev/null || true; brew tap quisharoo/office-check-in 2>/dev/null || brew tap quisharoo/office-check-in "https://github.com/Quisharoo/office-check-In"; brew update; mkdir -p "$HOME/Applications"; if brew list --cask quisharoo/office-check-in/office-check-in >/dev/null 2>&1; then brew upgrade --cask --appdir="$HOME/Applications" quisharoo/office-check-in/office-check-in; else brew install --cask --appdir="$HOME/Applications" quisharoo/office-check-in/office-check-in; fi; APP="$HOME/Applications/OfficeCheckIn.app"; [ -d "$APP" ] || APP="/Applications/OfficeCheckIn.app"; xattr -cr "$APP" 2>/dev/null || true; killall OfficeCheckIn 2>/dev/null || true; open "$APP"
```

> Note: `xattr` is needed because the app is not notarized.
>
> This command installs to `~/Applications` (better for work devices without admin).
>
> Work-managed Macs with `sudo` blocked: if you previously installed an older copy to `/Applications`,
> Homebrew may try to remove `/Applications/OfficeCheckIn.app` during upgrade and fail (because that
> requires admin rights). In that case, use the Manual install below to `~/Applications` (no admin).

### Manual

Download from [Releases](https://github.com/Quisharoo/office-check-In/releases/latest), unzip, and move to `~/Applications` (recommended for work machines), then run:

```bash
mkdir -p "$HOME/Applications"
xattr -cr "$HOME/Applications/OfficeCheckIn.app"
killall OfficeCheckIn 2>/dev/null || true
open "$HOME/Applications/OfficeCheckIn.app"
```

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



