#!/bin/bash
# Builds NotchIsland.app and NotchIsland.dmg into ./build.
#   ./build.sh            build, then launch the app
#   ./build.sh --no-open  build only (used by CI)
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Compiling (release, Apple silicon)…"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/NotchIsland"

APP="build/NotchIsland.app"
echo "▸ Assembling $APP…"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchIsland"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"

echo "▸ Creating build/NotchIsland.dmg…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "NotchIsland" -srcfolder "$STAGE" -ov -format UDZO build/NotchIsland.dmg >/dev/null
rm -rf "$STAGE"

echo "✓ Built $APP and build/NotchIsland.dmg"
if [[ "${1:-}" != "--no-open" ]]; then
  pkill -x NotchIsland 2>/dev/null || true
  open "$APP"
fi
