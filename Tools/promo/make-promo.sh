#!/usr/bin/env bash
# Makes the 30-second promo film: build/promo/BRBuddy-promo-wide.mp4 (1920x1080) and BRBuddy-promo-tall.mp4
# (1080x1920, for Reels, TikTok and Shorts).
# The frames are drawn by the debug app itself (PromoFilm.swift) with the real companion code; the music is
# synthesised by music.py. Needs ffmpeg and python3 with numpy.
set -euo pipefail
cd "$(dirname "$0")/../.."

out=build/promo
frames="$out/frames"
rm -rf "$frames"
mkdir -p "$frames"

swift build
BRBUDDY_PROMO="$PWD/$frames" .build/debug/BRBuddy >/dev/null
python3 Tools/promo/music.py "$frames"

for cut in wide tall; do
    ffmpeg -loglevel error -y -framerate 30 -i "$frames/$cut/%04d.png" -i "$frames/soundtrack.wav" \
        -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart \
        "$out/BRBuddy-promo-$cut.mp4"
    echo "made $out/BRBuddy-promo-$cut.mp4"
done
