# Design — `.app` packaging & unsigned `.dmg` distribution

**Date:** 2026-07-03
**Status:** Approved
**Scope:** Turn the SPM build into a distributable `NotchBar.app` packaged in a `.dmg`, with a real app icon, for unsigned / ad-hoc distribution. First step of the public-distribution roadmap.

## Goal

Produce a downloadable `NotchBar.dmg` that a user can install by dragging into `/Applications`. The pipeline must be reusable as-is when Developer ID signing + notarization are added later — no rework, only two extra steps on the same script.

## Constraints & context

- **No Apple Developer account** (not planned for this iteration). Therefore: no Developer ID signing, no notarization. Gatekeeper will require a one-time **right-click → Open** on first launch. This is the single accepted non-professional compromise, forced by the missing account.
- SPM-only project (no `.xcodeproj`). `swift build` emits a bare executable, **not** an `.app` bundle — the bundle must be assembled by hand.
- App keeps its existing internal name **NotchBar** everywhere (executable, `CFBundleIdentifier` `com.periicles.NotchBar`, display name). No renaming.
- Existing assets: `Supporting/Info.plist` (contains the Xcode variable `$(EXECUTABLE_NAME)` that must be resolved), `Supporting/NotchBar.entitlements` (app-sandbox + calendars).
- Target: macOS 14+.

## Non-goals (YAGNI for this iteration)

- Developer ID signing + notarization (deferred until an Apple account exists).
- CI integration of packaging (building the `.dmg` on tag) — belongs to the later "Release" step.
- Custom graphical `.dmg` background.

## Components

### 1. App icon — "Nightfall"

The approved concept: a macOS squircle, near-black vertical gradient evoking the physical notch, with a black notch tab at top and a single green progress bar below (sample event at 62%).

**Pipeline:** 1024×1024 SVG master → rasterized PNG → multi-resolution iconset (16/32/128/256/512 @1x + @2x) → `NotchBar.icns` via `iconutil`.

**Storage:** the SVG source and the generated `NotchBar.icns` live in `Supporting/Icon/` and are **committed** to the repo. The `.icns` is generated once, not rebuilt on every packaging run — so packaging has no SVG-rendering dependency.

Palette: `#0B0C10`, `#242833`, `#2B303B`, `#37D67A`, `#59E8A0`.

### 2. `scripts/package.sh` — single-entry pipeline

One idempotent script, commented in sections, run as `./scripts/package.sh`. Cleans its output dir first. Steps:

1. **Build** — `swift build -c release` → optimized `NotchBar` binary.
2. **Assemble bundle** — construct:
   ```
   NotchBar.app/Contents/
     ├── MacOS/NotchBar          # the release binary
     ├── Resources/NotchBar.icns # the committed icon
     └── Info.plist              # EXECUTABLE_NAME resolved → "NotchBar",
                                 # CFBundleIconFile → "NotchBar"
   ```
   The `$(EXECUTABLE_NAME)` placeholder is substituted with the literal `NotchBar`, and `CFBundleIconFile` is added so the icon is picked up.
3. **Ad-hoc sign** — `codesign --sign - --options runtime --entitlements Supporting/NotchBar.entitlements --deep NotchBar.app`. Applies the sandbox entitlements and makes the bundle runnable on Apple Silicon. (Structured so that swapping `-` for a Developer ID identity + adding a `notarytool` step later is the only change needed.)
4. **Package** — `hdiutil` builds `NotchBar.dmg` containing the `.app` and a symlink to `/Applications`.

**Output:** everything under `dist/` (git-ignored).

### 3. Signing reality (documented, not a bug)

Ad-hoc signing **does**: make the app runnable on Apple Silicon, apply sandbox entitlements.
Ad-hoc signing **does not**: remove the Gatekeeper first-launch warning → user must right-click → Open once. Removing that requires Developer ID + notarization (out of scope).

### 4. Install notice

A new **Installation** section in `README.md` explaining the download → drag to Applications → right-click → Open flow, with a plain-language note on why the warning appears and that it is safe.

## Acceptance criteria

Verified end-to-end before the work is considered done:

1. `./scripts/package.sh` runs clean and produces `dist/NotchBar.dmg`.
2. The `.dmg` mounts and shows `NotchBar.app` + an `/Applications` shortcut.
3. `NotchBar.app` carries the Nightfall icon at Finder sizes (16→512).
4. `codesign --verify NotchBar.app` passes (ad-hoc).
5. The app launches (via right-click → Open) and renders the notch as before.
6. README Installation section is present and accurate.

No unit tests (shell pipeline); acceptance is behavioral, verified manually.

## Future hook

When an Apple Developer account is obtained: replace the ad-hoc identity in step 3 with the Developer ID Application certificate, add a `notarytool submit --wait` + `stapler staple` step after packaging. Same script, no structural change.
