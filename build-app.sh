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

# Signing identity. Prefer a stable one so macOS keeps the notification grant
# across rebuilds (ad-hoc regenerates the identity every build, losing it):
#   $SIGN_ID set        -> use it (e.g. a Developer ID, or "-" to force ad-hoc)
#   setup-signing cert  -> use it automatically
#   otherwise           -> ad-hoc, with a hint to run ./setup-signing.sh
SIGN_KEYCHAIN="$HOME/Library/Keychains/magnetize-signing.keychain-db"
SIGN_NAME="Magnetize Local Signing"
SIGN_KC=""   # set only when signing from our dedicated keychain
if [[ -n "${SIGN_ID:-}" ]]; then
    IDENTITY="$SIGN_ID"
elif security find-identity -p codesigning "$SIGN_KEYCHAIN" 2>/dev/null | grep -q "$SIGN_NAME"; then
    # No -v: the cert is self-signed/untrusted (fine to sign with) so it won't
    # show as a "valid" identity, but codesign still uses it and produces a
    # stable designated requirement that survives rebuilds.
    IDENTITY="$SIGN_NAME"
    SIGN_KC="$SIGN_KEYCHAIN"
    security unlock-keychain -p "" "$SIGN_KEYCHAIN" 2>/dev/null || true
else
    IDENTITY="-"
fi

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

# 4) code-sign (must be last; any later edit invalidates it). A stable signed
#    identity is what lets macOS remember the notification grant across rebuilds.
if [[ -n "$SIGN_KC" ]]; then
    codesign --force --sign "$IDENTITY" --keychain "$SIGN_KC" "$BUILD"
else
    codesign --force --sign "$IDENTITY" "$BUILD"
fi

echo "Built $BUILD"
if [[ "$IDENTITY" == "-" ]]; then
    echo "  (ad-hoc signed — notification permission resets on each rebuild;"
    echo "   run ./setup-signing.sh once for a stable identity that keeps it.)"
else
    echo "  (signed as \"$IDENTITY\")"
fi

# 5) optional install
if [[ "${1:-}" == "--install" ]]; then
    rm -rf "$DEST"
    cp -R "$BUILD" "$DEST"
    "$LSREG" -f "$DEST"
    touch "$DEST"
    echo "Installed $DEST (registered as the magnet: and .torrent handler)"
fi
