#!/bin/bash
# build-icon.sh — regenerates Magnetize.icns from draw-icon.swift.
# Run this if you change the icon design; then run ../build-app.sh to install it.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER="$DIR/magnetize-1024.png"
ICONSET="$DIR/magnetize.iconset"

# 1) render the 1024px master from the Swift source
swift "$DIR/draw-icon.swift" "$MASTER"

# 2) produce every size Apple's .icns expects
rm -rf "$ICONSET"; mkdir "$ICONSET"
gen() { sips -z "$1" "$1" "$MASTER" --out "$ICONSET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

# 3) assemble the .icns (this is what build-app.sh installs)
iconutil -c icns "$ICONSET" -o "$DIR/Magnetize.icns"
echo "built $DIR/Magnetize.icns"
