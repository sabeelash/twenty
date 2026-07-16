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

codesign --force --sign - "$APP"

echo "Built $APP"
