#!/bin/zsh
# Builds Twenty.app into build/ from the SwiftPM executable.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Twenty.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/Twenty" "$APP/Contents/MacOS/Twenty"
cp "Support/Info.plist" "$APP/Contents/Info.plist"

# App icon: compile the Icon Composer file (Liquid Glass layers + .icns
# fallback). actool ships with full Xcode only; if the selected developer
# tools lack it (e.g. Command Line Tools), fall back to /Applications/Xcode.app.
# Skip gracefully when no toolchain provides it.
if ! xcrun --find actool > /dev/null 2>&1 && [[ -d "/Applications/Xcode.app" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app"
fi
if ACTOOL="$(xcrun --find actool 2>/dev/null)"; then
  ACTOOL_PARTIAL_PLIST="$APP/Contents/actool-partial.plist"
  "$ACTOOL" "Assets/twenty-icon.icon" \
    --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 26.0 \
    --app-icon twenty-icon --include-all-app-icons \
    --output-partial-info-plist "$ACTOOL_PARTIAL_PLIST" \
    --output-format human-readable-text > /dev/null
  /usr/libexec/PlistBuddy -c "Merge $ACTOOL_PARTIAL_PLIST" "$APP/Contents/Info.plist"
  rm "$ACTOOL_PARTIAL_PLIST"
else
  echo "warning: actool not found in selected developer tools; app icon not embedded" >&2
fi

codesign --force --sign - "$APP"

echo "Built $APP"
