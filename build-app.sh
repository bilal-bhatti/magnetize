#!/bin/bash
# build-app.sh — (re)builds and installs Magnetize.app from handler.applescript
# and icon/Magnetize.icns. Re-run this after editing either of those.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="Magnetize"
BUNDLE_ID="com.local.magnetize"
BUILD="$DIR/$NAME.app"
DEST="/Applications/$NAME.app"
PLIST="$BUILD/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# 1) compile the AppleScript into an app bundle
rm -rf "$BUILD"
osacompile -o "$BUILD" "$DIR/handler.applescript"

# 2) declare the magnet: URL scheme
$PB -c "Add :CFBundleURLTypes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLName string Magnet Link" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string magnet" "$PLIST"

# 3) identity + display name
$PB -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST"
$PB -c "Set :CFBundleName $NAME" "$PLIST"
$PB -c "Add :CFBundleDisplayName string $NAME" "$PLIST"

# 4) run as a background agent (no Dock icon)
$PB -c "Add :LSUIElement bool true" "$PLIST"

# 5) install our icon; drop the stock applet icon so it can't win
cp "$DIR/icon/$NAME.icns" "$BUILD/Contents/Resources/$NAME.icns"
rm -f "$BUILD/Contents/Resources/applet.icns"
$PB -c "Set :CFBundleIconFile $NAME" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleIconFile string $NAME" "$PLIST"
$PB -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true

# 6) bundle the engine INSIDE the app so it is self-contained (no repo dependency)
cp "$DIR/send-magnet.sh" "$BUILD/Contents/Resources/send-magnet.sh"
chmod +x "$BUILD/Contents/Resources/send-magnet.sh"

# 7) ad-hoc code-sign (must be last — any later edit invalidates the signature).
#    A stable signed identity is what lets the app's notifications appear.
codesign --force --deep --sign - "$BUILD"

# 8) install into /Applications and register with Launch Services
rm -rf "$DEST"
mv "$BUILD" "$DEST"
"$LSREG" -f "$DEST"
touch "$DEST"

echo "Installed $DEST  (bundle id: $BUNDLE_ID, self-contained, ad-hoc signed)"
