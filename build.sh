#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/CodexStatusBar.app"
BIN="$APP/Contents/MacOS/CodexStatusBar"
DMG="build/CodexStatusBar.dmg"
BUILD_DMG=0

if [[ "${1:-}" == "--dmg" ]]; then
  BUILD_DMG=1
elif [[ "${1:-}" != "" ]]; then
  echo "usage: ./build.sh [--dmg]" >&2
  exit 2
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling CodexStatusBar..."
swiftc -O -target arm64-apple-macos12.0 Sources/*.swift -o "$BIN" -framework Cocoa

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CodexStatusBar</string>
  <key>CFBundleDisplayName</key><string>Codex Status Bar</string>
  <key>CFBundleIdentifier</key><string>gaobo.gl.codex-status-bar</string>
  <key>CFBundleExecutable</key><string>CodexStatusBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleVersion</key><string>0.1.7</string>
  <key>CFBundleShortVersionString</key><string>0.1.7</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp assets/status-icons/codexTemplate.png "$APP/Contents/Resources/codexTemplate.png"
cp assets/status-icons/codexTemplate@2x.png "$APP/Contents/Resources/codexTemplate@2x.png"
cp scripts/codex-status-writer.js "$APP/Contents/Resources/codex-status-writer.js"
cp scripts/codex-lifecycle-writer.js "$APP/Contents/Resources/codex-lifecycle-writer.js"
cp scripts/install-codex-statusbar.js "$APP/Contents/Resources/install-codex-statusbar.js"
cp scripts/uninstall-codex-statusbar.js "$APP/Contents/Resources/uninstall-codex-statusbar.js"
rm -rf "$APP/Contents/Resources/lib"
cp -R scripts/lib "$APP/Contents/Resources/lib"
chmod +x "$APP/Contents/Resources/codex-status-writer.js"
chmod +x "$APP/Contents/Resources/codex-lifecycle-writer.js"
chmod +x "$APP/Contents/Resources/install-codex-statusbar.js"
chmod +x "$APP/Contents/Resources/uninstall-codex-statusbar.js"

xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"

if [[ "$BUILD_DMG" == "1" ]] && command -v hdiutil >/dev/null 2>&1; then
  rm -f "$DMG"
  tmp_dmg_dir="build/dmg"
  rm -rf "$tmp_dmg_dir"
  mkdir -p "$tmp_dmg_dir"
  cp -R "$APP" "$tmp_dmg_dir/CodexStatusBar.app"
  ln -s /Applications "$tmp_dmg_dir/Applications"
  hdiutil create -volname "Codex Status Bar" -srcfolder "$tmp_dmg_dir" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$tmp_dmg_dir"
  echo "Built $DMG"
fi
