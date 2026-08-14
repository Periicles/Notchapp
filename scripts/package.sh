#!/usr/bin/env bash
# Builds NotchBar.app and packages it into dist/NotchBar.dmg (unsigned / ad-hoc).
#
# Usage: package.sh [SHORT_VERSION] [BUILD_NUMBER]
#   SHORT_VERSION  overrides CFBundleShortVersionString (e.g. 0.2.0). CI passes
#                  the value from the git tag; omit for a local dev build.
#   BUILD_NUMBER   overrides CFBundleVersion (e.g. the CI run number).
# With no args the bundle keeps whatever Supporting/Info.plist declares.
#
# When an Apple Developer ID exists, swap `--sign -` for the identity and add a
# `notarytool submit --wait` + `stapler staple` step after the dmg build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="NotchBar"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"
SHORT_VERSION="${1:-}"
BUILD_NUMBER="${2:-}"

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

if [ -n "$SHORT_VERSION" ]; then
  echo "==> Setting version $SHORT_VERSION"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VERSION" "$CONTENTS/Info.plist"
fi
if [ -n "$BUILD_NUMBER" ]; then
  echo "==> Setting build $BUILD_NUMBER"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"
fi

echo "==> Verifying the app can find its resources"
# The app resolves localized strings from Contents/Resources. When this bundle
# is missing, every string silently degrades to its key — or the app traps at
# launch if anything still reaches for SwiftPM's Bundle.module.
for lproj in en fr; do
  test -f "$CONTENTS/Resources/${APP_NAME}_${APP_NAME}.bundle/$lproj.lproj/Localizable.strings" \
    || { echo "error: $lproj.lproj missing from the packaged resource bundle" >&2; exit 1; }
done

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
