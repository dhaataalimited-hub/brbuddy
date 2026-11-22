#!/usr/bin/env bash
# Makes Sparkle's command-line tools (generate_keys, generate_appcast, sign_update) available at build/sparkle-tools.
# They come from the Sparkle binary artifact SwiftPM downloads with the package and checks against the checksum pinned in
# Sparkle's manifest, so nothing unverified is downloaded. build/sparkle-tools is a link to that copy.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
artifact="$root/.build/artifacts/sparkle/Sparkle"
if [ ! -x "$artifact/bin/generate_appcast" ]; then swift package resolve; fi
if [ ! -x "$artifact/bin/generate_appcast" ]; then swift build -c release --product BRBuddy; fi
[ -x "$artifact/bin/generate_appcast" ] || { echo "error: Sparkle tools not found in $artifact" >&2; exit 1; }
mkdir -p build
rm -rf build/sparkle-tools
ln -s "$artifact" build/sparkle-tools
echo "Sparkle tools in $root/build/sparkle-tools/bin"
