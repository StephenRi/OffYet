#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

CONFIG=release
TRIPLE_DIR="menubar/.build/arm64-apple-macosx/$CONFIG"
APP="menubar/build/OffYet.app"
VERSION=$(sed -n 's/^public let version = "\(.*\)"$/\1/p' menubar/Sources/OffYetCore/OffYetCore.swift)

echo "==> swift build -c $CONFIG"
swift build -c $CONFIG --package-path menubar

echo "==> assemble $APP (v$VERSION)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TRIPLE_DIR/OffYetApp" "$APP/Contents/MacOS/OffYet"

ICONSET="menubar/build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
SRC="assets/offyet-logo-1024.png"
sips -z 16 16    "$SRC" --out "$ICONSET/icon_16x16.png"     >/dev/null
sips -z 32 32    "$SRC" --out "$ICONSET/icon_16x16@2x.png"  >/dev/null
sips -z 32 32    "$SRC" --out "$ICONSET/icon_32x32.png"     >/dev/null
sips -z 64 64    "$SRC" --out "$ICONSET/icon_32x32@2x.png"  >/dev/null
sips -z 128 128  "$SRC" --out "$ICONSET/icon_128x128.png"   >/dev/null
sips -z 256 256  "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256  "$SRC" --out "$ICONSET/icon_256x256.png"   >/dev/null
sips -z 512 512  "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512  "$SRC" --out "$ICONSET/icon_512x512.png"   >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>OffYet</string>
    <key>CFBundleDisplayName</key><string>下班了么</string>
    <key>CFBundleIdentifier</key><string>local.offyet.menubar</string>
    <key>CFBundleExecutable</key><string>OffYet</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>OffYet</string>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP"

echo "Built: $APP"
if [ "${1:-}" = "--install" ]; then
    osascript -e 'tell application "OffYet" to quit' 2>/dev/null || true
    sleep 1
    rm -rf /Applications/OffYet.app
    cp -R "$APP" /Applications/OffYet.app
    open /Applications/OffYet.app
    echo "Installed and launched: /Applications/OffYet.app"
fi
