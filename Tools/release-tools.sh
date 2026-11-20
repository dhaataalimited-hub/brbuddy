#!/usr/bin/env bash
# Downloads Sparkle's command-line tools (generate_keys, generate_appcast, sign_update) into build/sparkle-tools,
# from Sparkle's official GitHub release. Tools/release.sh does this itself when needed.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="2.10.1"
tools="$root/build/sparkle-tools"
if [ -x "$tools/bin/generate_appcast" ]; then echo "Sparkle tools already in $tools"; exit 0; fi
mkdir -p "$tools"
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" | tar -xJ -C "$tools"
echo "Sparkle $version tools in $tools/bin"
