#!/usr/bin/env bash
# Captures the hero screenshot used on the landing page (docs/assets/hero.png).
#
# Usage:
#   capture-hero.sh                      capture directly, after a countdown
#   capture-hero.sh --from <shot.png>    crop an existing full-screen screenshot
#   capture-hero.sh --delay 8            seconds before the direct capture fires
#
# NotchBar must be running: the crop region is read from the panel's real window
# rather than hardcoded, so it cannot drift from the app's geometry.
#
# The direct mode needs Screen Recording permission for your terminal (System
# Settings > Privacy & Security > Screen Recording). Without it, screencapture
# fails with "could not create image from rect" — use --from instead: take a
# full-screen shot with Cmd-Shift-5 (Options > Timer, so the panel stays open),
# then pass the file. That path needs no permission at all.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/assets/hero.png"
DELAY=6
FROM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from)  FROM="${2:-}"; shift 2 ;;
    --delay) DELAY="${2:-}"; shift 2 ;;
    *) echo "error: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

# Margin around the panel, in points: enough menu bar on either side for the
# notch to read as a notch, and a little desktop underneath.
SIDE_MARGIN=150
BOTTOM_MARGIN=40

read -r X Y W H SCREEN_W SCALE <<EOF
$(swift - "$SIDE_MARGIN" "$BOTTOM_MARGIN" <<'SWIFT'
import AppKit
import CoreGraphics

let sideMargin = CGFloat(Double(CommandLine.arguments[1])!)
let bottomMargin = CGFloat(Double(CommandLine.arguments[2])!)

let screen = NSScreen.screens.first(where: {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    guard let id = $0.deviceDescription[key] as? CGDirectDisplayID else { return false }
    return CGDisplayIsBuiltin(id) != 0
}) ?? NSScreen.main!

// The panel is the widest window NotchBar owns; the other is the hover sensor.
guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write(Data("error: cannot list windows\n".utf8))
    exit(1)
}
let panels = list
    .filter { ($0[kCGWindowOwnerName as String] as? String) == "NotchBar" }
    .compactMap { $0[kCGWindowBounds as String] as? [String: CGFloat] }
    .sorted { ($0["Width"] ?? 0) > ($1["Width"] ?? 0) }

guard let panel = panels.first, let pw = panel["Width"], let ph = panel["Height"] else {
    FileHandle.standardError.write(Data("error: NotchBar is not running\n".utf8))
    exit(1)
}

// Window bounds are already top-left origin, and the panel bleeds 2pt above the
// screen, so clamp the top edge to 0.
let x = max((panel["X"] ?? 0) - sideMargin, 0)
let y = max(panel["Y"] ?? 0, 0)
let width = min(pw + sideMargin * 2, screen.frame.width - x)
let height = ph + bottomMargin

print("\(Int(x)) \(Int(y)) \(Int(width)) \(Int(height)) \(Int(screen.frame.width)) \(Int(screen.backingScaleFactor))")
SWIFT
)
EOF

echo "==> Region: ${W}x${H} pt at (${X},${Y}) — screen ${SCREEN_W}pt @${SCALE}x"
mkdir -p "$(dirname "$OUT")"

if [ -n "$FROM" ]; then
  [ -f "$FROM" ] || { echo "error: no such file: $FROM" >&2; exit 1; }

  SHOT_W=$(sips -g pixelWidth "$FROM" | awk '/pixelWidth/{print $2}')
  # A full-screen shot spans the screen, so its own width gives the true
  # pixel-per-point ratio — more reliable than assuming the backing scale.
  RATIO=$(awk -v a="$SHOT_W" -v b="$SCREEN_W" 'BEGIN{printf "%.6f", a/b}')
  echo "==> Cropping $FROM (${SHOT_W}px wide, ${RATIO} px/pt)"

  px() { awk -v v="$1" -v r="$RATIO" 'BEGIN{printf "%d", v*r+0.5}'; }
  sips -c "$(px "$H")" "$(px "$W")" --cropOffset "$(px "$Y")" "$(px "$X")" \
    "$FROM" --out "$OUT" >/dev/null
else
  echo "==> Capturing in ${DELAY}s — hover the notch now and keep the cursor on it"
  screencapture -T "$DELAY" -x -R "$X,$Y,$W,$H" "$OUT" || {
    echo "error: screencapture failed. Grant Screen Recording to your terminal," >&2
    echo "       or take a full-screen shot with Cmd-Shift-5 and pass --from." >&2
    exit 1
  }
fi

OUT_W=$(sips -g pixelWidth "$OUT" | awk '/pixelWidth/{print $2}')
OUT_H=$(sips -g pixelHeight "$OUT" | awk '/pixelHeight/{print $2}')
echo "==> Done: $OUT (${OUT_W}x${OUT_H}px)"
[ "$OUT_W" -lt 1000 ] && echo "warning: under 1000px wide — it will look soft on a retina display" >&2
echo "    Commit it, and the landing page picks it up automatically."
exit 0
