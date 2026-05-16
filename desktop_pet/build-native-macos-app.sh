#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="PatchletNative"
APP_DIR="dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES/assets"

swiftc macos/PatchletNative.swift -o "$MACOS/$APP_NAME" -framework AppKit -framework ImageIO
cp assets/*.webp "$RESOURCES/assets/"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>PatchletNative</string>
  <key>CFBundleIdentifier</key>
  <string>run.crafter.patchlet.native</string>
  <key>CFBundleName</key>
  <string>Patchlet Native</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null
echo "Built $APP_DIR"
