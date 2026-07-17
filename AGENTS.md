# Repository Guidelines

## Project Structure & Module Organization

`Sources/Twenty/` contains the Swift executable. Keep app behavior close to its
owner: `BreakScheduler.swift` manages timer state, `OverlayController.swift`
manages per-display overlays, and `SettingsView.swift` owns the SwiftUI form.
`Assets/` holds SVG artwork and the Icon Composer bundle; `Support/Info.plist`
defines the menu-bar-only app; `Scripts/build-app.sh` assembles `build/Twenty.app`.

## Build, Test, and Development Commands

- `swift build` builds the debug executable with Swift Package Manager.
- `./Scripts/build-app.sh` builds and ad-hoc signs the release app at
  `build/Twenty.app`; run `open build/Twenty.app` to launch it.
- `./Scripts/build-app.sh debug` assembles a debug app bundle.
- `TWENTY_WORK_SECONDS=5 TWENTY_BREAK_SECONDS=5 ./build/Twenty.app/Contents/MacOS/Twenty`
  uses short intervals for manual timer testing.

Run the unit tests with `swift test`. XCTest ships with full Xcode only; if
`xcode-select` points at the Command Line Tools, use
`DEVELOPER_DIR=/Applications/Xcode.app swift test`. Scheduler and settings
logic is covered in `Tests/TwentyTests/`; still verify overlay, menu, and wake
behavior manually.

## Coding Style & Naming Conventions

Use four-space indentation and follow the existing Swift style: `UpperCamelCase`
for types, `lowerCamelCase` for methods and properties, and descriptive file
names that match their primary type. Keep UI code in SwiftUI views and AppKit
window/menu integration in controllers. There is no configured formatter or
linter; match nearby code and avoid unrelated reformatting.

## Testing Guidelines

Add focused XCTest coverage under `Tests/TwentyTests/` for deterministic timing
or settings logic. Name test methods by behavior, such as
`testPauseRemindersClearsNextBreakDate()`. For UI-affecting changes, include
manual test notes and use the environment overrides above to avoid long waits.

## Commit & Pull Request Guidelines

Recent commits use short, imperative summaries (for example, `Add Liquid Glass
app icon`). Keep each commit scoped to one change. Pull requests should explain
the behavioral impact, link relevant issues, list build/manual checks performed,
and include screenshots for settings, menu, or overlay changes. Do not commit
generated `build/` output.
