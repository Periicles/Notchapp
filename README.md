# NotchBar

Minimalist macOS app that uses the physical notch to show progress on the current calendar event.

## What it does

- Pick one or more calendars (checkboxes in Settings).
- If a tracked calendar is deleted or unshared, NotchBar won't auto-pick a replacement — reselect one in Settings.
- English and French, following the system language.
- Respects **Reduce Motion**: with it on, the panel crossfades in place — no scale, offset or spring — and the progress bar's shimmer is frozen.
- At rest NotchBar draws nothing in the notch — the physical notch shows through untouched (so it never slides with the desktop during Space switches).
- **Menu-bar countdown** (on by default, toggle in Settings): while an event is running, the time left shows next to the menu-bar icon — `23 min`, then `1h05` past the hour. No event running, or the toggle off, and it's the icon alone.
- **Event notifications** (off by default, toggle in Settings): a notification 5 minutes before a tracked event starts, and 5 minutes before it ends. Turning it on is what asks macOS for notification permission. Events shorter than 5 minutes only get the start one.
- On hover, the panel expands and shows one of seven contextual states, computed across the events of every tracked calendar:

| State | Trigger | Shown |
|---|---|---|
| **In progress** | Event overlaps now | Title, start–end times, animated progress bar, elapsed / remaining + **Join** button when a meeting link is detected (Zoom, Meet, Teams, Webex) |
| **Starting soon** | Next event in ≤ 5 minutes | `Starts in Xm — <title>` + **Join** button when a meeting link is detected (Zoom, Meet, Teams, Webex) |
| **Upcoming today** | Next event later today | `Next: <title> in Xh Ymin` |
| **Upcoming** | Next event is beyond today (up to 7 days out) | `Next event in: DD:HH:MM:SS` (live countdown) |
| **Empty today** | No events found | `No event today` |
| **No calendar** | No calendars selected | `Pick a calendar in Settings` |
| **Access off** | Calendar access denied or revoked | `Calendar access is off — re-enable in Settings` |

## Project layout

```
Sources/
├── NotchBarApp.swift              # @main + AppDelegate + the menu-bar status item
├── NotchPanel/                    # NSPanel windows, hover tracking, SwiftUI rendering, motion style
├── Calendar/                      # EventKit access, snapshot model, meeting links, notifications
├── Settings/                      # UserDefaults-backed preferences + settings UI
├── Utilities/                     # ScreenHelper (notch geometry), Localized helper, os.Logger categories
└── Resources/                     # en.lproj/ + fr.lproj/ Localizable.strings, processed natively by SwiftPM
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

**Seven-state snapshot model**
`EventProgressModel` holds an `EventProgressSnapshot` — an immutable, `Equatable` value derived from live EventKit data. `CalendarManager` maps EventKit into plain `CalendarEvent` values; `SnapshotBuilder` turns those into a snapshot; the view renders whatever snapshot it receives. All conditional logic is isolated in `SnapshotBuilder.computeSnapshot`, making each state independently testable without a running EventKit store.

**Data flow**
```
EventKit → CalendarManager → EventProgressSnapshot → NotchPanelView
```
`CalendarManager` owns `EKEventStore`, publishes the fetch window as `[CalendarEvent]` values, and polls every 30s — paused while the screens are asleep, with one catch-up refresh on wake — plus reacts to `EKEventStoreChanged`. If Calendar access is granted after launch — e.g. from System Settings, without restarting NotchBar — the store-changed notification and each panel open re-check authorization and pick up the change automatically. `NotchPanelView` observes `EventProgressModel` via `@ObservedObject`.

**Idle-first performance**
The 1-second refresh tick and the 60fps progress-bar shimmer run **only while the panel is open** (hover). While collapsed, the only live work is the menu-bar countdown's tick — one snapshot recompute every 30 seconds, matching `CalendarManager`'s polling cadence, and only while the toggle is on. Turn the countdown off and NotchBar does no live work at all when collapsed. Snapshots are `Equatable`, so redundant recomputes never trigger a SwiftUI invalidation.

**`LSUIElement`**
Set in `Info.plist`, this flag hides the app from the Dock and the Cmd-Tab app switcher. NotchBar runs as a pure background UI layer with no Dock presence.

## Installation

NotchBar is ad-hoc signed, not Apple-notarized — notarization needs a paid Apple Developer ID and is not planned. That only matters for **downloads made by a browser**, which macOS tags with a quarantine flag Gatekeeper then refuses. The two command-line routes below never set that flag, so they install and launch with no prompt at all.

### Homebrew (recommended)

```sh
brew tap periicles/tap
brew trust periicles/tap          # third-party casks need an explicit trust (Homebrew 6+)
brew install --cask --no-quarantine notchbar
```

`--no-quarantine` is what skips the Gatekeeper prompt. Update with `brew upgrade --cask notchbar`; remove with `brew uninstall --cask notchbar` (add `--zap` to also delete its data).

### One command, without Homebrew

```sh
curl -fsSL -o /tmp/NotchBar.dmg https://github.com/Periicles/Notchapp/releases/latest/download/NotchBar.dmg &&
hdiutil attach -quiet -nobrowse -mountpoint /tmp/NotchBar.mount /tmp/NotchBar.dmg &&
cp -R /tmp/NotchBar.mount/NotchBar.app /Applications/ &&
hdiutil detach -quiet /tmp/NotchBar.mount && rm /tmp/NotchBar.dmg
```

Nothing is piped into a shell — every step is visible above. `curl` does not set the quarantine flag, so the app opens with a normal double-click afterwards.

### Manual (`.dmg`)

1. Download [NotchBar.dmg](https://github.com/Periicles/Notchapp/releases/latest/download/NotchBar.dmg), or get it from the [NotchBar website](https://periicles.github.io/Notchapp/).
2. Open the `.dmg` and drag **NotchBar** into your **Applications** folder.
3. Open NotchBar. The first time, macOS blocks it — expected for an unsigned app downloaded through a browser.
4. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**, then confirm.

> **Why the extra step?** The app is unsigned, so Gatekeeper rejects the quarantine flag your browser attached to the download. You do this once; afterwards it opens with a normal double-click. Either command-line route above avoids the step entirely.

On first launch, grant Calendar access when prompted, then hover over the notch and click the settings icon to choose which calendars to track.

## Uninstall

1. If you turned on **Launch at login**, hover the notch → open settings → toggle it **off** first (this removes the login item cleanly). You can also remove it later under **System Settings → General → Login Items**.
2. Quit NotchBar: click the NotchBar icon in the menu bar → **Quit**, or hover the notch → open settings → **Quit NotchBar**.
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

On first launch, grant Calendar access when the system prompt appears (or later via **System Settings → Privacy & Security → Calendars**). Then hover over the physical notch and click the settings icon to choose which calendars to track.

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

**Refreshing the landing page screenshot**

`docs/assets/hero.png` is the shot at the top of the [website](https://periicles.github.io/Notchapp/). Until it exists the page falls back to a CSS mockup, so the site is never broken by a missing file.

Run NotchBar, open a calendar event so the panel shows the **in progress** state — title, times and progress bar, which is the whole point of the shot — then:

```sh
scripts/capture-hero.sh            # counts down, then captures; hover the notch and hold
```

The crop region is read from the panel's real window, so it cannot drift from the app's geometry.

Direct capture needs Screen Recording permission for your terminal. Without it `screencapture` fails with *could not create image from rect* — take a full-screen shot instead (**⌘⇧5 → Options → Timer**, so the panel stays open while it fires) and crop that, which needs no permission:

```sh
scripts/capture-hero.sh --from ~/Desktop/Screenshot*.png
```

Check what you are about to publish: the shot includes the menu bar on either side of the notch, and the panel shows real event titles.

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
5. Add an entry under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) when behavior changes

The CI pipeline (lint → build → test) runs automatically on every PR. A PR cannot be merged with a failing CI.

## Releasing

Releases are cut by pushing a tag. A GitHub Actions workflow (`.github/workflows/release.yml`) then lints, builds, tests, packages the `.dmg`, and publishes a GitHub Release automatically.

```sh
git tag v0.3.0
git push origin v0.3.0
```

The version comes from the tag (`vX.Y.Z` → `X.Y.Z`) and is injected into the app at build time — no need to edit `Info.plist`. The `CFBundleShortVersionString` checked into `Supporting/Info.plist` is only a placeholder for local `swift run` builds; every packaged build overwrites it. Releases are published as stable, which is what keeps `/releases/latest/download/NotchBar.dmg` resolving — that URL skips pre-releases.

**Notarization is not planned** — it needs a paid Apple Developer ID, and the command-line install routes already avoid the Gatekeeper prompt. Kept here in case that ever changes: add these repository secrets and follow the commented hooks in `release.yml` / `scripts/package.sh`.

| Secret | For |
|---|---|
| `MACOS_CERT_P12_BASE64` | Developer ID Application cert (`.p12`), base64-encoded |
| `MACOS_CERT_PASSWORD` | the `.p12` password |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | `notarytool` credentials |

## License

NotchBar is released under the [MIT License](LICENSE).
