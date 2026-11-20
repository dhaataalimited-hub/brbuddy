#!/usr/bin/env bash
# Builds BRBuddy.app into build/ from the Swift package.
#
# Usage: Tools/build-app.sh [debug|release]   (default: release)
#
# Environment (all optional):
#   SIGN_IDENTITY       codesign identity. Default "-" (ad hoc: runs on this Mac only). Any other identity, e.g.
#                       "Developer ID Application: Name (TEAMID)", also turns on the hardened runtime and a secure
#                       timestamp, as notarization requires.
#   VERSION             marketing version. Default: the latest vX.Y.Z git tag without the "v", else 0.1.0.
#   UNIVERSAL=1         build for Apple silicon and Intel (release builds for distribution).
#   SPARKLE_PUBLIC_KEY  Sparkle EdDSA public key. With it the app gets the update feed and checks for updates;
#                       without it (local builds) there's no updater at all.
#   SPARKLE_FEED_URL    default: the appcast attached to the latest GitHub release.
set -euo pipefail

config="${1:-release}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

identity="${SIGN_IDENTITY:--}"
version="${VERSION:-$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null | sed 's/^v//' || true)}"
version="${version:-0.1.0}"
build_number="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
feed="${SPARKLE_FEED_URL:-https://github.com/dhaataalimited-hub/brbuddy/releases/latest/download/appcast.xml}"

arch_flags=()
if [ "${UNIVERSAL:-0}" = "1" ]; then arch_flags=(--arch arm64 --arch x86_64); fi

swift build -c "$config" ${arch_flags[@]+"${arch_flags[@]}"}
binDir="$(swift build -c "$config" ${arch_flags[@]+"${arch_flags[@]}"} --show-bin-path)"

app="build/BRBuddy.app"
contents="$app/Contents"
rm -rf "$app"
mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Helpers" "$contents/Frameworks"

# Executables.
cp "$binDir/BRBuddy" "$contents/MacOS/BRBuddy"
cp "$binDir/brbuddy-hook" "$contents/Helpers/brbuddy-hook"

# Info.plist with version, and the update feed only when there's a Sparkle key.
plist="$contents/Info.plist"
cp Config/Info.plist "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist"
if [ -n "${SPARKLE_PUBLIC_KEY:-}" ]; then
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $feed" "$plist"
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$plist"
    /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" "$plist"
fi

# Dependencies' resource bundles (KeyboardShortcuts' translations) go in Resources, where Bundle.module finds them.
for bundle in "$binDir"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$contents/Resources/"
done
# Licences shipped with the app.
cp LICENSE THIRD_PARTY_NOTICES.md "$contents/Resources/"

# Sparkle: embed the framework and point the app at Contents/Frameworks.
ditto "$binDir/Sparkle.framework" "$contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$contents/MacOS/BRBuddy"
# Drop build-machine-only search paths (the Xcode toolchain) from the shipped binary.
otool -l "$contents/MacOS/BRBuddy" | awk '/LC_RPATH/{getline; getline; print $2}' | grep '^/Applications/Xcode' | sort -u |
    while read -r path; do install_name_tool -delete_rpath "$path" "$contents/MacOS/BRBuddy" 2>/dev/null || true; done

# Sign inside out: Sparkle's helpers, the framework, our helper, then the app.
if [ "$identity" = "-" ]; then
    sign=(codesign --force --sign -)
else
    sign=(codesign --force --options runtime --timestamp --sign "$identity")
fi
sparkle="$contents/Frameworks/Sparkle.framework/Versions/B"
"${sign[@]}" "$sparkle/XPCServices/Installer.xpc"
"${sign[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
"${sign[@]}" "$sparkle/Autoupdate"
"${sign[@]}" "$sparkle/Updater.app"
"${sign[@]}" "$contents/Frameworks/Sparkle.framework"
"${sign[@]}" "$contents/Helpers/brbuddy-hook"
"${sign[@]}" "$app"
codesign --verify --strict --deep "$app"

echo "Built $root/$app (version $version, build $build_number, signed with: $identity)"
