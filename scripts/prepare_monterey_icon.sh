#!/bin/bash
set -euo pipefail

# The Icon Composer source requires newer asset tooling. Reuse the upstream
# raster logo to produce a classic icon understood by macOS Monterey.
icon_work=$(mktemp -d)
trap 'rm -rf "$icon_work"' EXIT
iconset="$icon_work/Monterey.iconset"
mkdir -p "$iconset"
for side in 16 32 128 256 512; do
  sips -s format png -z "$side" "$side" docs/images/logo.png \
    --out "$iconset/icon_${side}x${side}.png" >/dev/null
  doubled=$((side * 2))
  sips -s format png -z "$doubled" "$doubled" docs/images/logo.png \
    --out "$iconset/icon_${side}x${side}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Docky/Monterey.icns
