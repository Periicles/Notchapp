# App Packaging & Unsigned DMG — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the SPM build into a distributable `NotchBar.app` packaged in `dist/NotchBar.dmg`, with the approved "Nightfall" icon, for unsigned / ad-hoc distribution.

**Architecture:** Two committed shell scripts. `scripts/make-icon.sh` rasterizes a committed SVG into `NotchBar.icns` (run only when the icon changes; dev-time dependency on `rsvg-convert`). `scripts/package.sh` runs the release build → hand-assembles the `.app` bundle → ad-hoc signs with entitlements → builds a compressed `.dmg`. The `.icns` is committed so packaging has no SVG-render dependency. Ad-hoc signing is structured so adding Developer ID + notarization later is a two-line change.

**Tech Stack:** Bash, Swift Package Manager (`swift build`), `rsvg-convert` (librsvg), `sips`/`iconutil`, `codesign`, `hdiutil`, `PlistBuddy`.

## Global Constraints

- Platform floor: macOS 14; Swift tools 6.1. Verify builds with `swift build -c release`.
- App identity is **NotchBar** everywhere — executable `NotchBar`, `CFBundleIdentifier` `com.periicles.NotchBar`, display name `NotchBar`. No renaming.
- **No Apple Developer account** this iteration: ad-hoc signing only (`codesign --sign -`). No Developer ID, no notarization. First launch requires right-click → Open — this is expected, not a bug.
- Build artifacts go under `dist/` and must be git-ignored.
- Icon source SVG + generated `.icns` live in `Supporting/Icon/` and are committed.
- Existing assets to reuse verbatim: `Supporting/Info.plist` (has `$(EXECUTABLE_NAME)` to resolve), `Supporting/NotchBar.entitlements` (app-sandbox + calendars).
- Spec: `docs/superpowers/specs/2026-07-03-app-packaging-design.md`.

---

### Task 1: Nightfall icon → `NotchBar.icns`

**Files:**
- Create: `Supporting/Icon/NotchBar.svg`
- Create: `scripts/make-icon.sh`
- Create (generated, committed): `Supporting/Icon/NotchBar.icns`

**Interfaces:**
- Produces: `Supporting/Icon/NotchBar.icns` — the app icon consumed by Task 2.

- [ ] **Step 1: Install the SVG renderer (one-time dev dependency)**

Run: `brew install librsvg`
Expected: `rsvg-convert` becomes available. Verify: `command -v rsvg-convert` prints a path.

- [ ] **Step 2: Create the icon source SVG**

Create `Supporting/Icon/NotchBar.svg` with exactly this content (the approved "Nightfall" mark, 1024×1024, event at 62%):

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#242833"/>
      <stop offset="1" stop-color="#0B0C10"/>
    </linearGradient>
    <linearGradient id="fill" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#37D67A"/>
      <stop offset="1" stop-color="#59E8A0"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="230" fill="url(#bg)"/>
  <rect x="5" y="5" width="1014" height="1014" rx="227" fill="none"
        stroke="#FFFFFF" stroke-opacity="0.06" stroke-width="2"/>
  <path d="M352 236 h320 v58 a40 40 0 0 1 -40 40 h-240 a40 40 0 0 1 -40 -40 z" fill="#000000"/>
  <rect x="262" y="566" width="500" height="72" rx="36" fill="#2B303B"/>
  <rect x="262" y="566" width="310" height="72" rx="36" fill="url(#fill)"/>
</svg>
```

- [ ] **Step 3: Create the icon build script**

Create `scripts/make-icon.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Regenerates Supporting/Icon/NotchBar.icns from NotchBar.svg.
# Run only when the icon design changes. Requires: rsvg-convert (brew install librsvg).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="$ROOT/Supporting/Icon"
SVG="$ICON_DIR/NotchBar.svg"
OUT="$ICON_DIR/NotchBar.icns"
ICONSET="$(mktemp -d)/NotchBar.iconset"

command -v rsvg-convert >/dev/null || {
  echo "rsvg-convert not found. Run: brew install librsvg" >&2; exit 1;
}

mkdir -p "$ICONSET"

# The ten name/size pairs macOS requires in an .iconset, rendered straight from SVG.
render() { rsvg-convert -w "$1" -h "$1" "$SVG" -o "$ICONSET/$2"; }
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"
```

- [ ] **Step 4: Make it executable and run it**

Run:
```bash
chmod +x scripts/make-icon.sh
./scripts/make-icon.sh
```
Expected: prints `Wrote .../Supporting/Icon/NotchBar.icns`.

- [ ] **Step 5: Verify the icns is valid and multi-resolution**

Run: `iconutil -c iconset Supporting/Icon/NotchBar.icns -o /tmp/verify.iconset && ls /tmp/verify.iconset`
Expected: ten PNGs listed (`icon_16x16.png` … `icon_512x512@2x.png`). Clean up: `rm -rf /tmp/verify.iconset`.

- [ ] **Step 6: Commit**

```bash
git add scripts/make-icon.sh Supporting/Icon/NotchBar.svg Supporting/Icon/NotchBar.icns
git commit -m "feat(icon): add Nightfall app icon and generator script"
```

---

### Task 2: `package.sh` — build, bundle, sign, dmg

**Files:**
- Create: `scripts/package.sh`
- Modify: `.gitignore` (append `dist/`)

**Interfaces:**
- Consumes: `Supporting/Icon/NotchBar.icns` (Task 1), `Supporting/Info.plist`, `Supporting/NotchBar.entitlements`, release binary at `swift build -c release --show-bin-path`/`NotchBar`.
- Produces: `dist/NotchBar.dmg` — the distributable, consumed by users (and referenced by Task 3's README).

- [ ] **Step 1: Ignore the build output**

Append to `.gitignore` (new line at end of file):
```
# Packaged distribution artifacts
dist/
```

- [ ] **Step 2: Create the packaging script**

Create `scripts/package.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Builds NotchBar.app and packages it into dist/NotchBar.dmg (unsigned / ad-hoc).
# When an Apple Developer ID exists, swap `--sign -` for the identity and add a
# `notarytool submit --wait` + `stapler staple` step after the dmg build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="NotchBar"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> Cleaning dist/"
rm -rf "$DIST"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "==> Building release binary"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Assembling $APP_NAME.app"
cp "$BIN_DIR/$APP_NAME"                    "$CONTENTS/MacOS/$APP_NAME"
cp "Supporting/Icon/$APP_NAME.icns"        "$CONTENTS/Resources/$APP_NAME.icns"
cp "Supporting/Info.plist"                 "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $APP_NAME" "$CONTENTS/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile $APP_NAME" "$CONTENTS/Info.plist"

echo "==> Ad-hoc signing (applies sandbox entitlements)"
codesign --force --sign - --options runtime \
  --entitlements "Supporting/$APP_NAME.entitlements" "$APP"
codesign --verify --strict "$APP"

echo "==> Building .dmg"
STAGE="$DIST/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$APP_NAME.dmg"
rm -rf "$STAGE"

echo "==> Done: $DIST/$APP_NAME.dmg"
```

- [ ] **Step 3: Make it executable and run it**

Run:
```bash
chmod +x scripts/package.sh
./scripts/package.sh
```
Expected: ends with `==> Done: .../dist/NotchBar.dmg`. No `codesign` error (the `--verify --strict` line must pass).

- [ ] **Step 4: Verify the dmg contents and signature**

Run:
```bash
test -f dist/NotchBar.dmg && echo "dmg exists"
hdiutil attach dist/NotchBar.dmg -nobrowse -mountpoint /tmp/nb_dmg
ls /tmp/nb_dmg                     # expect: Applications  NotchBar.app
codesign --verify --strict /tmp/nb_dmg/NotchBar.app && echo "codesign OK"
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" /tmp/nb_dmg/NotchBar.app/Contents/Info.plist   # expect: NotchBar
/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" /tmp/nb_dmg/NotchBar.app/Contents/Info.plist # expect: NotchBar
hdiutil detach /tmp/nb_dmg
```
Expected: `dmg exists`, the `ls` shows `Applications` and `NotchBar.app`, `codesign OK`, both plist values print `NotchBar`.

- [ ] **Step 5: Verify the app launches (locally built = not quarantined)**

Run:
```bash
open dist/NotchBar.app
sleep 2
pgrep -x NotchBar && echo "running"
osascript -e 'quit app "NotchBar"' 2>/dev/null || pkill -x NotchBar
```
Expected: `running` printed (process started). If a Calendar permission prompt appears, that is correct behavior.

- [ ] **Step 6: Commit**

```bash
git add scripts/package.sh .gitignore
git commit -m "feat(packaging): add package.sh building unsigned NotchBar.dmg"
```

---

### Task 3: README installation section

**Files:**
- Modify: `README.md` (add an `## Installation` section before `## Getting Started`)

**Interfaces:**
- Consumes: the `dist/NotchBar.dmg` distribution flow (Task 2) and the right-click → Open reality of ad-hoc apps.

- [ ] **Step 1: Add the Installation section**

Insert this section into `README.md` immediately **before** the `## Getting Started` heading:

```markdown
## Installation

1. Download the latest `NotchBar.dmg` from the [Releases](https://github.com/Periicles/Notchapp/releases) page.
2. Open the `.dmg` and drag **NotchBar** into your **Applications** folder.
3. **First launch:** right-click (or Control-click) NotchBar in Applications and choose **Open**, then confirm **Open** in the dialog that appears.

> **Why the extra step?** NotchBar isn't notarized by Apple yet, so macOS asks you to confirm the very first launch. It's a one-time step — after that, NotchBar opens normally. (Notarization is on the roadmap.)

On first launch, grant Calendar access when prompted, then hover over the notch and click the settings icon to choose a calendar.

```

- [ ] **Step 2: Verify it renders**

Run: `grep -n "## Installation" README.md`
Expected: one match, positioned before the `## Getting Started` line (confirm with `grep -n "## Getting Started" README.md` showing a higher line number).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): add installation instructions for the dmg"
```

---

## Self-Review

**Spec coverage:**
- Icon (Nightfall SVG → `.icns`, committed, `Supporting/Icon/`) → Task 1. ✓
- `scripts/package.sh` linear pipeline (build → bundle → resolve plist → ad-hoc sign w/ entitlements → dmg) → Task 2. ✓
- `dist/` git-ignored → Task 2 Step 1. ✓
- Signing reality documented + future notarization hook → package.sh header comment (Task 2). ✓
- Install notice (README) → Task 3. ✓
- Acceptance criteria (dmg exists, mounts, icon present, codesign verifies, launches, README present) → Task 2 Steps 4–5 + Task 3 Step 2. ✓
- Out-of-scope (notarization, CI, custom dmg background) → correctly absent. ✓

**Placeholder scan:** No TBD/TODO; all script and SVG content is complete and literal. ✓

**Type/name consistency:** `NotchBar` used verbatim across executable, icns filename, `CFBundleExecutable`, `CFBundleIconFile`, dmg volname; icns path `Supporting/Icon/NotchBar.icns` consistent between Task 1 (produces) and Task 2 (consumes). ✓
