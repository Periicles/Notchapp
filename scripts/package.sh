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
cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$CONTENTS/Resources/"
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
