#!/usr/bin/env bash
# Builds a signed, notarized BRBuddy-<version>.dmg and a Sparkle appcast in build/release/.
# Used by .github/workflows/release.yml; also runs on a Mac with the certificate in its keychain.
#
# Usage: Tools/release.sh <version>        e.g. Tools/release.sh 0.2.0
#
# Required environment:
#   SIGN_IDENTITY        "Developer ID Application: Name (TEAMID)"
#   SPARKLE_PUBLIC_KEY   Sparkle EdDSA public key (also in docs/releasing.md)
# Notarization, one of:
#   NOTARY_PROFILE                          a profile saved with `xcrun notarytool store-credentials` (local), or
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID   an App Store Connect API key (CI)
# Appcast signing, one of:
#   SPARKLE_PRIVATE_KEY_PATH   file holding the Sparkle private key (CI), or nothing: generate_appcast then uses
#                              the key in this Mac's keychain (local)
# Optional:
#   SKIP_NOTARIZE=1      sign and package only (dry runs)
#   SPARKLE_TOOLS        folder with Sparkle's bin/generate_appcast (default: the copy SwiftPM fetched and checksum-
#                        verified with the Sparkle dependency, .build/artifacts/sparkle/Sparkle)
set -euo pipefail
trap 'echo "error: ${BASH_SOURCE[0]}:$LINENO: \"$BASH_COMMAND\" failed" >&2' ERR

version="${1:?usage: Tools/release.sh <version, e.g. 0.2.0>}"
version="${version#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must look like 1.2.3, not '$version'" >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

: "${SIGN_IDENTITY:?set SIGN_IDENTITY to your Developer ID Application identity}"
: "${SPARKLE_PUBLIC_KEY:?set SPARKLE_PUBLIC_KEY}"
repo_url="https://github.com/dhaataalimited-hub/brbuddy"

out="build/release"
rm -rf "$out"
mkdir -p "$out"

# 1. Universal app, signed with the hardened runtime.
VERSION="$version" UNIVERSAL=1 SIGN_IDENTITY="$SIGN_IDENTITY" SPARKLE_PUBLIC_KEY="$SPARKLE_PUBLIC_KEY" \
    Tools/build-app.sh release

# Sends a file to Apple's notary service and waits for the verdict.
notarize() {
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
    else
        : "${NOTARY_KEY_PATH:?set NOTARY_PROFILE, or NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER_ID}"
        xcrun notarytool submit "$1" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" \
            --issuer "$NOTARY_ISSUER_ID" --wait
    fi
}

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# 2. Notarize the app itself and staple its ticket, so a copy dragged out of the disk image opens even offline.
if [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
    ditto -c -k --keepParent build/BRBuddy.app "$staging/BRBuddy.zip"
    notarize "$staging/BRBuddy.zip"
    rm "$staging/BRBuddy.zip"
    xcrun stapler staple build/BRBuddy.app
    xcrun stapler validate build/BRBuddy.app
fi

# 3. Disk image with the stapled app and an Applications shortcut, then notarize and staple the image too.
dmg="$out/BRBuddy-$version.dmg"
mkdir "$staging/dmg"
ditto build/BRBuddy.app "$staging/dmg/BRBuddy.app"
ln -s /Applications "$staging/dmg/Applications"
hdiutil create -volname "BRBuddy" -srcfolder "$staging/dmg" -ov -format UDZO "$dmg" >/dev/null
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
if [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
    notarize "$dmg"
    xcrun stapler staple "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose "$dmg"
fi

# 4. Sparkle appcast pointing at this release's download.
# The tools come from the Sparkle binary artifact SwiftPM already downloaded and checked against the checksum pinned in
# Sparkle's package manifest: nothing unverified runs while the signing keys are loaded.
tools="${SPARKLE_TOOLS:-.build/artifacts/sparkle/Sparkle}"
if [ ! -x "$tools/bin/generate_appcast" ]; then
    echo "error: $tools/bin/generate_appcast not found; run swift build first" >&2
    exit 1
fi
key_args=()
if [ -n "${SPARKLE_PRIVATE_KEY_PATH:-}" ]; then key_args=(--ed-key-file "$SPARKLE_PRIVATE_KEY_PATH"); fi
# generate_appcast mounts the disk image. Right after stapling and spctl, macOS can still be holding it and the mount
# fails with "Resource busy"; a failed attempt also leaves an empty folder in Sparkle's cache that the next attempt
# trusts. So clear that cache and try a few times.
for attempt in 1 2 3 4 5; do
    rm -rf "$HOME/Library/Caches/Sparkle_generate_appcast"
    if "$tools/bin/generate_appcast" ${key_args[@]+"${key_args[@]}"} \
        --download-url-prefix "$repo_url/releases/download/v$version/" \
        --link "$repo_url" "$out"; then
        break
    fi
    if [ "$attempt" = 5 ]; then echo "error: generate_appcast failed 5 times" >&2; exit 1; fi
    echo "generate_appcast failed (attempt $attempt); retrying in 10 s" >&2
    sleep 10
done
[ -f "$out/appcast.xml" ] || { echo "error: generate_appcast made no appcast.xml" >&2; exit 1; }
# Sparkle ignores unsigned updates, so an unsigned appcast would silently break updates for everyone.
if [ "${SKIP_NOTARIZE:-0}" != "1" ] && ! grep -q 'sparkle:edSignature' "$out/appcast.xml"; then
    echo "error: appcast.xml isn't signed; set SPARKLE_PRIVATE_KEY_PATH or add the key to this Mac's keychain" >&2
    exit 1
fi

# 5. Homebrew cask values.
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
sed -e "s/@VERSION@/$version/g" -e "s/@SHA256@/$sha/g" packaging/homebrew/brbuddy.rb > "$out/brbuddy.rb"

echo "Release files in $root/$out:"
ls -1 "$out"
