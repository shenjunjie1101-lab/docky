# Docky 0.9.7 — Simplified Chinese Monterey compatibility build

This fork targets macOS 12.6 on Apple Silicon. It is an experimental source
port of upstream tag `v0.9.7`, not an official Docky release.

## Validation status

The GitHub Actions workflow compiles with a macOS 12.6 deployment target and
checks the resulting ARM64 executable's minimum OS version and ad hoc signature.
A successful workflow does **not** constitute testing on macOS 12.6. Window
management, permissions, magnification, multi-display behavior and the built-in
widgets still need testing on a real Monterey Mac.

## Changes and limits

- On macOS 12/13, app activation preserves the caller's options and adds
  `activateIgnoringOtherApps` for explicit dock actions. Already-running apps
  with empty accessibility window lists receive activation before reopening;
  rejected activation requests fall back to NSWorkspace. CI checks the legacy
  option construction and switching from a Safari page to running/hidden apps
  with both accessory and regular Docky activation policies.
- Perception 1.6.0 replaces the macOS 14 Observation runtime, including tracking
  inside lazy SwiftUI view builders and the AppKit observation bridge.
- Settings, corner shapes, geometry observation, path helpers, delays, app
  activation and calendar/reminder requests have Monterey-compatible versions.
- Pointer magnification uses a 60 Hz timer that stops when the pointer rests.
- The main panel explicitly sets AppKit's native window level, remains visible
  when another app activates, and is ordered forward without taking focus.
  CI checks its WindowServer layer and stacking against an overlapping normal
  window, including after Finder activation; user-selected autohide and
  fullscreen visibility rules still apply.
- Context menus use the public AppKit presentation API before macOS 26. Menu
  actions that remove or ungroup a tile run after menu tracking unwinds; ungroup
  also deduplicates imported member IDs. CI exercises 30 native-menu group and
  ungroup cycles across grid, list and inline presentation, plus an imported
  duplicate-member case.
- Monterey uses ordinary scrolling with explicit page buttons, without the newer
  snapping behavior. Adaptive widget content uses its compact presentation.
- Window snapshots first use the existing CoreGraphics capture path. The newer
  ScreenCaptureKit screenshot fallback is unavailable before macOS 14.
- The bundled Now Playing adapter requires macOS 15 and is not launched on
  Monterey; the widget displays an unavailable message.
- Automatic upstream updates are disabled because upstream releases require a
  newer operating system. New installations keep the system Dock visible.
- External widget bundles must themselves support macOS 12.6. A newer bundle
  does not become compatible simply because the host is compatible.

## Build

Use Xcode 26 on a supported build Mac; the target Mac may stay on macOS 12.6.

```sh
bash scripts/prepare_monterey_icon.sh
xcodebuild -project Docky.xcodeproj -scheme Docky \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build -skipMacroValidation -skipPackagePluginValidation \
  MACOSX_DEPLOYMENT_TARGET=12.6 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build
bash scripts/package_monterey.sh
```

The package script produces a ZIP and DMG in `dist/`. These local builds are ad
hoc signed and are not notarized by Apple. The upstream GPLv3 license applies;
included Perception and IssueReporting notices are preserved in the app bundle.

## Simplified Chinese edition

The app selects Simplified Chinese before AppKit loads its resources. Translation
covers the string catalog, native menu, privacy usage descriptions, built-in
catalog actions, permission guidance, status text, settings and widget labels.
Existing app names, user content, filenames and file paths are preserved.
The CI workflow validates format arguments and unchanged executable action data,
then renders seven settings pages and checks native Chinese resource lookup.
