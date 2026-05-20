# NotchBar

Minimalist macOS menu bar app that uses the physical notch to show progress on the current calendar event.

## What it does

- Picks one calendar from your Mac (radio-button selection in Settings).
- The notch stays solid black at rest — no information leaks until you hover.
- On hover, the panel expands and shows one of five contextual states:

| State | Trigger | Shown |
|---|---|---|
| **In progress** | Event overlaps now | Title, start–end times, animated progress bar, elapsed / remaining |
| **Starting soon** | Next event in ≤ 5 minutes | `Starts in Xm — <title>` |
| **Upcoming today** | Next event later today | `Next: <title> in Xh Ymin` |
| **Empty today** | Nothing scheduled until tomorrow | `No event today` |
| **No calendar** | No calendar selected | `Pick a calendar in Settings` |

## Project layout

```
Sources/
├── NotchBarApp.swift              # @main + AppDelegate
├── NotchPanel/                    # NSPanel windows, hover tracking, SwiftUI rendering
├── Calendar/                      # EventKit access + event snapshot model
├── Settings/                      # UserDefaults-backed preferences + settings UI
└── Utilities/ScreenHelper.swift   # Physical notch geometry
Tests/
└── NotchBarTests/                 # XCTest target (@testable import NotchBar)
Supporting/
├── Info.plist                     # LSUIElement, calendars usage description, bundle metadata
└── NotchBar.entitlements          # Sandbox + calendars entitlement
```

## Building

Requires macOS 14, Swift 6.1+, Xcode (for XCTest when running tests).

```sh
swift build
swift run
```

## Running tests

The test target depends on `XCTest`, which is shipped with full Xcode (not Command Line Tools). If `xcode-select -p` points at `/Library/Developer/CommandLineTools`, set `DEVELOPER_DIR` for the test invocation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Or switch globally:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift test
```

## Permissions

On first launch the app requests Calendar access via EventKit. Grant it in the prompt or later in `System Settings > Privacy & Security > Calendars`.
