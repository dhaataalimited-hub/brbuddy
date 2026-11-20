#!/usr/bin/env bash
# Builds BRBuddy.app into build/ from the Swift package.
# Usage: Tools/build-app.sh [debug|release]   (default: release)
# Signs ad hoc, so it runs on this Mac. Developer ID signing and notarization come with the release pipeline.
set -euo pipefail

config="${1:-release}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

swift build -c "$config"
binDir="$(swift build -c "$config" --show-bin-path)"
bin="$binDir/BRBuddy"

app="build/BRBuddy.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/BRBuddy"
cp Config/Info.plist "$app/Contents/Info.plist"
# Dependencies' resource bundles (e.g. KeyboardShortcuts' translations) go in Resources, where Bundle.module finds them.
for bundle in "$binDir"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$app/Contents/Resources/"
done
codesign --force --sign - "$app"

echo "Built $root/$app"
