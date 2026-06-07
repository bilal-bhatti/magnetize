#!/bin/bash
# build-app.sh — compiles the Swift sources into Magnetize.app. No Xcode project:
# just swiftc + a hand-assembled bundle, so a clone builds with one command and
# only the Command Line Tools installed.
#
#   ./build-app.sh            build to ./build/Magnetize.app
#   ./build-app.sh --install  also install into /Applications and register the
#                             magnet: and .torrent handlers with Launch Services
#
# Re-run after editing anything in Sources/, Info.plist, or the icon.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="Magnetize"
MIN_OS="14.0"
ARCH="$(uname -m)"
BUILD="$DIR/build/$NAME.app"
CONTENTS="$BUILD/Contents"
DEST="/Applications/$NAME.app"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# 1) fresh bundle skeleton
rm -rf "$BUILD"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# 2) compile every Swift source into the bundle's executable
swiftc \
  -O \
  -parse-as-library \
  -target "${ARCH}-apple-macosx${MIN_OS}" \
  -o "$CONTENTS/MacOS/$NAME" \
  "$DIR"/Sources/*.swift

# 3) metadata + icon (Info.plist declares the magnet: scheme, .torrent type, LSUIElement)
cp "$DIR/Info.plist" "$CONTENTS/Info.plist"
cp "$DIR/icon/$NAME.icns" "$CONTENTS/Resources/$NAME.icns"

# 4) ad-hoc code-sign (must be last; any later edit invalidates it). A stable
#    signed identity is what lets the app post notifications under its own name.
codesign --force --sign - "$BUILD"

echo "Built $BUILD"

# 5) optional install
if [[ "${1:-}" == "--install" ]]; then
    rm -rf "$DEST"
    cp -R "$BUILD" "$DEST"
    "$LSREG" -f "$DEST"
    touch "$DEST"
    echo "Installed $DEST (registered as the magnet: and .torrent handler)"
fi
