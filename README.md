<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Assets/wordmark-dark.svg">
    <img src="Assets/wordmark-light.svg" alt="Twenty" width="204">
  </picture>
</p>

A native macOS menu bar utility that enforces the 20-20-20 rule: every 20 minutes,
a full-screen blurred overlay reminds you to look away from the screen for 20 seconds.

## Requirements

- macOS 26 (Tahoe) or later
- Swift 6 toolchain (Xcode 26 or Command Line Tools)

## Build & run

```sh
./Scripts/build-app.sh          # builds build/Twenty.app (release)
open build/Twenty.app
```

The app icon (`Assets/twenty-icon.icon`, an Icon Composer file) is compiled
into the bundle when full Xcode 26 is installed; with Command Line Tools only,
the build still works but skips the icon.

The app lives entirely in the menu bar (no Dock icon). Look for the eye icon.

## Behavior

- **Work timer** — starts at launch; default 20 minutes (configurable 5 min – 3 h).
- **Break overlay** — covers every display with a behind-window blur and dim,
  above all other windows. Shows a 20-second countdown with **Later** (snooze,
  default 5 min) and **Skip**.
- **Idle detection** — if you've been away from the keyboard/mouse for 3+ minutes
  when a break comes due, the break is skipped and a fresh work session starts
  when you return. Short pauses (reading, thinking) still count as work.
- **Sleep/wake** — sleeping through a break resets the timer instead of
  ambushing you on wake.
- **Settings** — work interval, break duration, snooze duration, launch at login.
  All stored in `UserDefaults`.

## Performance notes

While you work there is exactly one armed one-shot timer and zero polling.
A 1 Hz countdown timer runs only while the overlay is on screen, and a light
15-second idle poll runs only while you're away from the machine.

## Development

Environment overrides for quick testing (seconds):

```sh
TWENTY_WORK_SECONDS=5 TWENTY_BREAK_SECONDS=5 ./build/Twenty.app/Contents/MacOS/Twenty
```

## Project layout

- `Sources/Twenty/BreakScheduler.swift` — timing state machine (work → break → snooze, idle, sleep/wake)
- `Sources/Twenty/OverlayController.swift` — per-display overlay windows, fade in/out, countdown
- `Sources/Twenty/BreakCardView.swift` — SwiftUI break card ("Look away." / countdown / Later / Skip)
- `Sources/Twenty/StatusItemController.swift` — menu bar item and menu
- `Sources/Twenty/SettingsView.swift` — SwiftUI settings form
- `Support/Info.plist` — bundle manifest (`LSUIElement` = menu bar only)
- `Scripts/build-app.sh` — SwiftPM build + .app assembly + ad-hoc codesign
