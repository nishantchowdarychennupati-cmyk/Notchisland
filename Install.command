#!/bin/bash
# One-step installer: builds NotchIsland and installs it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swift >/dev/null 2>&1; then
  echo "Apple's developer tools are needed to build NotchIsland."
  echo "A window will open to install them. Run this installer again when that finishes."
  xcode-select --install || true
  exit 1
fi

./build.sh --no-open
pkill -x NotchIsland 2>/dev/null || true
rm -rf /Applications/NotchIsland.app
cp -R build/NotchIsland.app /Applications/
open /Applications/NotchIsland.app
echo ""
echo "✓ NotchIsland is installed in Applications and running. Hover over your notch!"
