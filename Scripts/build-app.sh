#!/bin/zsh
# Builds Twenty.app into build/ from the SwiftPM executable.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

APP="build/Twenty.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/$CONFIG/Twenty" "$APP/Contents/MacOS/Twenty"
cp "Support/Info.plist" "$APP/Contents/Info.plist"

# App icon: compile the Icon Composer file (Liquid Glass layers + .icns
# fallback). actool ships with full Xcode only, so skip gracefully without it.
XCODE_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"
if [[ -e "$XCODE_DIR/Contents/Developer/usr/bin/actool" ]]; then
  DEVELOPER_DIR="$XCODE_DIR" xcrun actool "Assets/twenty-icon.icon" \
    --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 26.0 \
    --app-icon twenty-icon --include-all-app-icons \
    --output-partial-info-plist "build/actool-partial.plist" \
    --output-format human-readable-text > /dev/null
else
  echo "warning: full Xcode not found; app icon not embedded" >&2
fi

codesign --force --sign - "$APP"

echo "Built $APP"
