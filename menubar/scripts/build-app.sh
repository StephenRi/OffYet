#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

CONFIG=release
TRIPLE_DIR="menubar/.build/arm64-apple-macosx/$CONFIG"
APP="menubar/build/OffYet.app"
VERSION=$(sed -n 's/^public let version = "\(.*\)"$/\1/p' menubar/Sources/OffYetCore/OffYetCore.swift)
[ -n "$VERSION" ] || { echo "error: cannot parse version from OffYetCore.swift" >&2; exit 1; }

DMG=0 RELEASE=0 INSTALL=0 DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dmg) DMG=1 ;;
        --release) RELEASE=1 DMG=1 ;;
        --install) INSTALL=1 ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "error: unknown flag: $arg (usage: build-app.sh [--dmg] [--release] [--install] [--dry-run])" >&2; exit 1 ;;
    esac
done

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

cp assets/offyet-logo-tile.png "$APP/Contents/Resources/OffYetLogo.png"

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

DMG_PATH=""
if [ "$DMG" -eq 1 ]; then
    DMG_PATH="menubar/build/OffYet-v$VERSION.dmg"
    STAGING="menubar/build/dmg-staging"
    echo "==> package DMG"
    rm -rf "$STAGING"; mkdir -p "$STAGING"
    cp -R "$APP" "$STAGING/OffYet.app"
    ln -s /Applications "$STAGING/Applications"
    rm -f "$DMG_PATH"
    hdiutil create -volname "OffYet" -srcfolder "$STAGING" -ov -quiet -format UDZO "$DMG_PATH"
    hdiutil verify -quiet "$DMG_PATH"
    rm -rf "$STAGING"
    echo "DMG: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1 | tr -d ' '))"
fi

if [ "$RELEASE" -eq 1 ]; then
    TAG="v$VERSION"
    REMOTE_URL=$(git remote get-url origin)
    REPO=${REMOTE_URL#*github.com[:/]}
    REPO=${REPO%.git}
    case "$REPO" in
        */*) ;;
        *) echo "error: cannot derive owner/repo from origin remote: $REMOTE_URL" >&2; exit 1 ;;
    esac

    # GitHub 在远端默认分支 HEAD 上自动建 tag，因此本地必须与 origin/main 同步
    git fetch -q origin
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || {
        echo "error: local main is not in sync with origin/main; push your commits first" >&2
        exit 1
    }

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "dry-run: would create release $TAG on $REPO (tag auto-created at origin/main) and upload $(basename "$DMG_PATH")"
        exit 0
    fi

    TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | GIT_TERMINAL_PROMPT=0 git credential fill | sed -n 's/^password=//p')
    [ -n "$TOKEN" ] || { echo "error: no GitHub credential available (git credential fill failed)" >&2; exit 1; }

    BODY_JSON=$(python3 - "$VERSION" <<'PY'
import json, sys
body = f"""macOS 菜单栏应用「下班了么」。

## 安装

1. 下载 OffYet-v{sys.argv[1]}.dmg 并打开
2. 将 OffYet 拖入 Applications 文件夹
3. 首次打开若被 Gatekeeper 拦截（应用为 ad-hoc 签名）：系统设置 → 隐私与安全性 → 仍要打开；或在终端执行 `xattr -dr com.apple.quarantine /Applications/OffYet.app`
"""
print(json.dumps(body))
PY
)

    echo "==> create release $TAG on $REPO"
    STATUS=$(curl -s -o /tmp/offyet-release.json -w '%{http_code}' -X POST \
        -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
        -d "{\"tag_name\":\"$TAG\",\"name\":\"OffYet v$VERSION\",\"body\":$BODY_JSON}" \
        "https://api.github.com/repos/$REPO/releases")
    if [ "$STATUS" != "201" ]; then
        # 同版本重跑时复用已有 release
        STATUS=$(curl -s -o /tmp/offyet-release.json -w '%{http_code}' \
            -H "Authorization: Bearer $TOKEN" \
            "https://api.github.com/repos/$REPO/releases/tags/$TAG")
    fi
    RELEASE_ID=$(python3 -c 'import json; print(json.load(open("/tmp/offyet-release.json")).get("id") or "")')
    if [ -z "$RELEASE_ID" ]; then
        echo "error: release API failed (HTTP $STATUS):" >&2; cat /tmp/offyet-release.json >&2; echo >&2; exit 1
    fi
    RELEASE_URL=$(python3 -c 'import json; print(json.load(open("/tmp/offyet-release.json"))["html_url"])')

    ASSET_NAME=$(basename "$DMG_PATH")
    ASSET_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "https://api.github.com/repos/$REPO/releases/$RELEASE_ID/assets" \
        | ASSET_NAME="$ASSET_NAME" python3 -c 'import json,os,sys; a=[x["id"] for x in json.load(sys.stdin) if x["name"]==os.environ["ASSET_NAME"]]; print(a[0] if a else "")')
    if [ -n "$ASSET_ID" ]; then
        echo "==> remove stale asset $ASSET_NAME"
        curl -s -o /dev/null -X DELETE -H "Authorization: Bearer $TOKEN" \
            "https://api.github.com/repos/$REPO/releases/$RELEASE_ID/assets/$ASSET_ID"
    fi

    echo "==> upload $ASSET_NAME"
    STATUS=$(curl -s -o /tmp/offyet-asset.json -w '%{http_code}' -X POST \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/x-apple-diskimage" \
        --data-binary "@$DMG_PATH" \
        "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$ASSET_NAME")
    if [ "$STATUS" != "201" ]; then
        echo "error: asset upload failed (HTTP $STATUS):" >&2; cat /tmp/offyet-asset.json >&2; echo >&2; exit 1
    fi

    rm -f /tmp/offyet-release.json /tmp/offyet-asset.json
    echo "Released: $RELEASE_URL"
fi

if [ "$INSTALL" -eq 1 ]; then
    osascript -e 'tell application "OffYet" to quit' 2>/dev/null || true
    sleep 1
    rm -rf /Applications/OffYet.app
    cp -R "$APP" /Applications/OffYet.app
    open /Applications/OffYet.app
    echo "Installed and launched: /Applications/OffYet.app"
fi
