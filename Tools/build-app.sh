#!/usr/bin/env bash
# Builds BRBuddy.app into build/ from the Swift package.
# Usage: Tools/build-app.sh [debug|release]   (default: release)
# Signs ad hoc, so it runs on this Mac. Developer ID signing and notarization come with the release pipeline.
set -euo pipefail

config="${1:-release}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift build -c "$config"
bin="$(swift build -c "$config" --show-bin-path)/BRBuddy"

app="build/BRBuddy.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/BRBuddy"
cp Config/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"

echo "Built $root/$app"
