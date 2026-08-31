# Changelog

All notable changes to NotchBar are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
NotchBar adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **The settings gear covered the event's end time.** The orb is a top-trailing
  overlay, so it painted over the in-progress layout's time range, which nothing
  inset out of its way — 24pt of a 109pt `14:00 - 15:00` disappeared under it.
  The orb is smaller (32pt → 26pt) and the title row now insets itself by a
  clearance derived from the orb's own size, so the two cannot drift apart again.

- **The documented Homebrew install no longer worked.** `--no-quarantine` was
  removed from Homebrew 6, so `brew install --cask --no-quarantine notchbar`
  fails outright with `Error: invalid option`. Homebrew now quarantines every
  cask unconditionally, which an ad-hoc signed app cannot survive: README and
  the landing page document `xattr -dr com.apple.quarantine` as the step that
  replaces the flag, and no longer claim the Homebrew route is prompt-free.
  The step repeats on every `brew upgrade` — Homebrew carries an unquarantined
  app forward only while its signing identity holds, and an ad-hoc signature is
  designated by a `cdhash` that each build changes.

## [0.3.2] - 2026-08-31

### Fixed

- **The automatic cask bump crashed on every release.** The job runs on Linux
  while the script is developed on macOS, and `mktemp -t <prefix>` — valid for
  BSD, which appends the random suffix itself — is rejected by GNU mktemp. CI
  now rehearses the real rewrite on Linux on every pull request.

## [0.3.1] - 2026-08-31

### Changed

- **Publishing a release now bumps the Homebrew cask on its own.** A `bump-cask`
  job hashes the released `.dmg`, opens a pull request on `Periicles/homebrew-tap`
  and turns on auto-merge, so it lands as soon as the tap's `brew test-bot` is
  green. `brew upgrade --cask notchbar` no longer waits on a manual bump.
- README documents how to update an existing install, per install route.

## [0.3.0] - 2026-08-15

### Added

- **Menu-bar countdown** (on by default): the time left on the running event
  shows next to the menu-bar icon — `23 min`, then `1h00` past the hour. It is
  the first NotchBar surface VoiceOver can reach; the panel is hover-only.
- **Event notifications** (off by default): a notification 5 minutes before a
  tracked event starts and 5 minutes before it ends. Turning the toggle on is
  what asks macOS for permission.

### Fixed

- **The packaged app crashed at launch on any machine but the one that built
  it.** SwiftPM's `Bundle.module` looks for the resource bundle beside
  `Bundle.main`'s bundle URL — the `.app` itself, not `Contents/Resources`
  where it is packaged — and otherwise falls back to the absolute `.build`
  path baked in at compile time. Localized strings resolved by accident on the
  developer's machine and trapped everywhere else. Present since localization
  shipped in 0.2.0, so **0.2.0's `.dmg` is affected**. Resources now resolve
  from the app bundle, and `package.sh` fails if they are missing.
- The notch's settings menu opened as an *inactive* window: switches rendered
  grey instead of accent-coloured and the translucent material sampled whatever
  sat behind the notch, so it read as a broken dark theme until the first click
  recoloured everything. The panel is a non-activating panel that cannot become
  key, so opening the menu now brings the app forward.
- Settings rows now put the label flush left and the control flush right, and
  the calendar checkboxes clear the scroller instead of sitting under it.
- An event that started more than 8 hours ago and is still running was invisible
  to the fetch predicate, so the panel showed the next event instead of the
  current one. The look-back is now 24 hours.
- The panel could show a stale state between polls: the manager kept only the
  current and next event, resolved at fetch time, so once one event ended and
  the one after next began, neither was the right answer. The whole fetched
  window is kept now.
- The `EKEventStoreChanged` observer was registered block-based and its token
  discarded, so `removeObserver(self)` never unregistered it.
- The 30s calendar poll ran on behind a sleeping display. It pauses on screen
  sleep and catches up with one refresh on wake.

### Changed

- SwiftLint is pinned in CI. `brew install swiftlint` tracked latest, so a new
  default rule could turn CI — and a release build — red with no code change.
- `MeetingLinkDetector`'s link scan ran on every 1s panel tick; it now runs once
  per calendar fetch.

## [0.2.0] - 2026-07-13

### Added

- Release workflow triggered by a `v*` tag, with the version injected from the
  tag at build time.
- French localization, following the system language.
- **Join** button when a meeting link is detected (Zoom, Meet, Teams, Webex).
- Multiple tracked calendars, with migration from the single-calendar setting.
- Reduce Motion support: the panel crossfades in place and the progress bar's
  shimmer freezes.
- `os.Logger` categories (calendar, panel, preferences). Event titles are never
  logged.
- Quit button in the settings panel.

### Fixed

- Calendar access recovers after launch: granting it in System Settings no
  longer needs a restart, and revoking it while running is detected.
- Write-only calendar access is reported as insufficient instead of being
  treated as granted — it cannot read events.
- `NSCalendarsFullAccessUsageDescription` added; macOS 14+ requires it for
  `requestFullAccessToEvents()`.
- The notch renders nothing at rest, so it no longer slides with the desktop
  during a Space switch.

## [0.1.0] - 2026-07-04

First public pre-release.

### Added

- Hover-expanded notch panel with live progress on the current calendar event.
- Calendar selection, launch at login, `.dmg` packaging and a landing page.

[Unreleased]: https://github.com/Periicles/Notchapp/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/Periicles/Notchapp/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/Periicles/Notchapp/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Periicles/Notchapp/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Periicles/Notchapp/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Periicles/Notchapp/releases/tag/v0.1.0
