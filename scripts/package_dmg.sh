#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "=== 1. Building SimpleProxy Release ==="
swift build -c release
mkdir -p SimpleProxy.app/Contents/MacOS
cp .build/release/SimpleProxy SimpleProxy.app/Contents/MacOS/SimpleProxy

echo "=== 2. Ad-hoc Codesigning SimpleProxy.app ==="
codesign --force --deep --sign - SimpleProxy.app

DIST_DIR="$DIR/dist"
mkdir -p "$DIST_DIR"

VERSION="1.0.0"
DMG_NAME="SimpleProxy-$VERSION.dmg"
FINAL_DMG="$DIST_DIR/$DMG_NAME"
LATEST_DMG="$DIST_DIR/SimpleProxy.dmg"
DESKTOP_DMG="$HOME/Desktop/SimpleProxy.dmg"
TMP_DMG="/tmp/SimpleProxy_rw.dmg"
BG_IMG="/tmp/dmg_background.png"
VOL_NAME="SimpleProxy"

echo "=== 3. Generating DMG Background Image ==="
swift "$DIR/scripts/generate_dmg_background.swift" "$BG_IMG"

echo "=== 4. Cleaning previous temporary files & mounts ==="
rm -f "$TMP_DMG" "$FINAL_DMG" "$LATEST_DMG"
if [ -d "/Volumes/$VOL_NAME" ]; then
    hdiutil detach "/Volumes/$VOL_NAME" -force || true
fi

echo "=== 5. Creating writable DMG image ==="
hdiutil create -size 30m -fs HFS+ -volname "$VOL_NAME" -ov "$TMP_DMG"

echo "=== 6. Mounting writable DMG ==="
ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG")
DEVICE=$(echo "$ATTACH_OUTPUT" | grep '^/dev/' | head -n 1 | awk '{print $1}')
MOUNT_DIR="/Volumes/$VOL_NAME"

echo "Mounted at: $MOUNT_DIR on device: $DEVICE"

echo "=== 7. Populating DMG content ==="
cp -R SimpleProxy.app "$MOUNT_DIR/"
ln -s /Applications "$MOUNT_DIR/Applications"

mkdir -p "$MOUNT_DIR/.background"
cp "$BG_IMG" "$MOUNT_DIR/.background/background.png"
SetFile -a V "$MOUNT_DIR/.background"

if [ -f "SimpleProxy.app/Contents/Resources/AppIcon.icns" ]; then
    cp "SimpleProxy.app/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_DIR"
    SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
fi

echo "=== 8. Configuring Finder Window Layout via AppleScript ==="
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {240, 160, 880, 580}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:background.png"
        set position of item "SimpleProxy.app" of container window to {150, 215}
        set position of item "Applications" of container window to {490, 215}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

sync
sleep 2

echo "=== 9. Detaching volume ==="
hdiutil detach "$DEVICE" -force

echo "=== 10. Compressing into final read-only DMG ==="
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -ov
rm -f "$TMP_DMG" "$BG_IMG"

cp "$FINAL_DMG" "$LATEST_DMG"
cp "$FINAL_DMG" "$DESKTOP_DMG"

echo "=== 11. Calculating Checksums ==="
FILESIZE=$(ls -lh "$FINAL_DMG" | awk '{print $5}')
SHA256=$(shasum -a 256 "$FINAL_DMG" | awk '{print $1}')

echo "=================================================="
echo "  SimpleProxy DMG Packaging Complete! "
echo "  File:     $FINAL_DMG"
echo "  Size:     $FILESIZE"
echo "  SHA256:   $SHA256"
echo "  Desktop:  $DESKTOP_DMG"
echo "=================================================="
