#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Mac Ai Usage"
APP="$ROOT/dist/$APP_NAME.app"

swift build --package-path "$ROOT" -c release --product mac-ai-usage
BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/mac-ai-usage" "$APP/Contents/MacOS/mac-ai-usage"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" ]; then
    ICONSET_DIR="$APP/Contents/Resources/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    sips -s format png -z 16 16     "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -s format png -z 32 32     "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -s format png -z 32 32     "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -s format png -z 64 64     "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -s format png -z 128 128   "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -s format png -z 256 256   "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -s format png -z 256 256   "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -s format png -z 512 512   "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -s format png -z 512 512   "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    sips -s format png -z 1024 1024 "$ROOT/Sources/MacAiUsageApp/Resources/AppIcon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
    
    iconutil -c icns "$ICONSET_DIR" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - "$APP"

echo "$APP"
