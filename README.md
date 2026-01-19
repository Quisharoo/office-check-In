# Office Check‑In

A macOS menubar app for tracking office attendance. Shows your flex percentage for the month/quarter and suggests days to hit your target.

## Install

### Homebrew

```bash
brew tap quisharoo/office-check-in https://github.com/Quisharoo/office-check-In
brew install --cask office-check-in
```

### Manual

Download from [Releases](https://github.com/Quisharoo/office-check-In/releases/latest), unzip, and move to `/Applications`.

### Troubleshooting

If the app disappears from your menu bar, relaunch it:

```bash
killall cfprefsd; open /Applications/OfficeCheckIn.app
```

---

![screenshot](screenshot.png)
