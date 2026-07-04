# NotchBar

Minimalist macOS app that uses the physical notch to show progress on the current calendar event.

## What it does

- Picks one calendar from your Mac (radio-button selection in Settings).
- The notch stays solid black at rest — no information leaks until you hover.
- On hover, the panel expands and shows one of six contextual states:

| State | Trigger | Shown |
|---|---|---|
| **In progress** | Event overlaps now | Title, start–end times, animated progress bar, elapsed / remaining |
| **Starting soon** | Next event in ≤ 5 minutes | `Starts in Xm — <title>` |
| **Upcoming today** | Next event later today | `Next: <title> in Xh Ymin` |
| **Upcoming tomorrow** | Next event is tomorrow or later | `Next event in: DD:HH:MM:SS` (live countdown) |
| **Empty today** | No events found | `No event today` |
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

## Architecture

NotchBar is intentionally simple — no external dependencies, no framework layers.

**SPM-only (no `.xcodeproj`)**
Swift Package Manager is the sole build system. This keeps builds fully reproducible and eliminates Xcode project file merge conflicts in team workflows.

**`NSPanel` over `NSWindow`**
The notch overlay is an `NSPanel` configured as `borderless` + `nonactivatingPanel`. This combination keeps the panel visible at the correct screen layer without stealing keyboard focus from the active app.

**Six-state snapshot model**
`EventProgressModel` holds an `EventProgressSnapshot` — an immutable, `Equatable` value derived from live EventKit data. `CalendarManager` computes the snapshot; the view renders whatever snapshot it receives. All conditional logic is isolated in `CalendarManager.computeSnapshot`, making each state independently testable without a running EventKit store.

**Data flow**
```
EventKit → CalendarManager → EventProgressSnapshot → NotchPanelView
```
`CalendarManager` owns `EKEventStore`, publishes `currentEvent` / `nextEvent`, and polls every 30s (plus reacts to `EKEventStoreChanged`). `NotchPanelView` observes `EventProgressModel` via `@ObservedObject`.

**Idle-first performance**
At rest the notch shows nothing from the snapshot, so NotchBar does no live work while collapsed: the 1-second refresh tick and the 60fps progress-bar shimmer both run **only while the panel is open** (hover). Snapshots are `Equatable`, so redundant recomputes never trigger a SwiftUI invalidation. Result: ~0% CPU when collapsed, even during an in-progress event.

**`LSUIElement`**
Set in `Info.plist`, this flag hides the app from the Dock and the Cmd-Tab app switcher. NotchBar runs as a pure background UI layer with no Dock presence.

## Installation

1. Grab it from the [NotchBar website](https://periicles.github.io/Notchapp/), or download the latest `NotchBar.dmg` from the [Releases](https://github.com/Periicles/Notchapp/releases) page.
2. Open the `.dmg` and drag **NotchBar** into your **Applications** folder.
3. Open NotchBar. The first time, macOS blocks it because the app isn't notarized yet.
4. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**, then confirm.

> **Why the extra step?** macOS blocks it only because NotchBar isn't notarized by Apple yet — it's safe, just unsigned. You do this once; afterwards it opens with a normal double-click. (Notarization is on the roadmap.)

On first launch, grant Calendar access when prompted, then hover over the notch and click the settings icon to choose a calendar.

## Uninstall

1. If you turned on **Launch at login**, hover the notch → open settings → toggle it **off** first (this removes the login item cleanly). You can also remove it later under **System Settings → General → Login Items**.
2. Quit NotchBar: hover the notch → open settings → **Quit NotchBar**. (It has no Dock or menu-bar icon; you can also quit it from Activity Monitor or by logging out.)
3. Drag **NotchBar** from **Applications** to the Trash.
4. *Optional — remove leftover settings:* delete `~/Library/Containers/com.periicles.NotchBar/`.
5. *Optional — revoke Calendar access:* **System Settings → Privacy & Security → Calendars**.

## Getting Started

**Prerequisites**

- macOS 14 or later
- [Xcode](https://developer.apple.com/xcode/) full install (required for XCTest and the Swift 6.1 toolchain)

**Clone, build, and run**

```sh
git clone https://github.com/Periicles/Notchapp.git
cd Notchapp
swift build
swift run
```

On first launch, grant Calendar access when the system prompt appears (or later via **System Settings → Privacy & Security → Calendars**). Then hover over the physical notch and click the settings icon to choose a calendar.

## Development

**Running tests**

The test target depends on `XCTest`, which ships with full Xcode (not Command Line Tools). If `xcode-select -p` points at `/Library/Developer/CommandLineTools`, set `DEVELOPER_DIR` for the test invocation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

**Linting**

Install [SwiftLint](https://github.com/realm/SwiftLint) and run it from the project root:

```sh
brew install swiftlint
swiftlint
```

The CI pipeline runs `swiftlint` on every PR. Fix all errors before pushing.

## Contributing

**Branch naming**

| Prefix | Use for |
|---|---|
| `feature/<topic>` | New functionality |
| `fix/<topic>` | Bug fixes |
| `docs/<topic>` | Documentation-only changes |
| `refactor/<topic>` | Code changes with no behavior change |

**Commit style** — [Conventional Commits](https://www.conventionalcommits.org)

```
feat: add weekly agenda view
fix: correct progress bar overflow at event boundary
refactor: extract snapshot helpers into static methods
test: cover upcomingToday state with same-day boundary
docs: document five-state model in README
```

**Before opening a PR**

1. `swift test` — all tests pass
2. `swiftlint` — zero errors
3. New non-trivial logic is covered by tests
4. One concern per PR — avoid mixing features with refactors

The CI pipeline (lint → build → test) runs automatically on every PR. A PR cannot be merged with a failing CI.

## License

NotchBar is released under the [MIT License](LICENSE).
