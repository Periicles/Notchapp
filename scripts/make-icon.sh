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
