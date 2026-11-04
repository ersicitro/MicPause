#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/MicPause.app"
[[ -x "$ROOT/build/MicPause" ]] || { echo "请先运行 bash script/build.sh" >&2; exit 1; }
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/build/MicPause" "$APP/Contents/MacOS/MicPause"
cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/"
cp "$ROOT/Assets/shh_menu_bar.png" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MicPause</string>
<key>CFBundleDisplayName</key><string>MicPause</string>
<key>CFBundleIdentifier</key><string>com.micpause.app</string>
<key>CFBundleExecutable</key><string>MicPause</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# No bundled certificates or account-specific signing identity. Local ad-hoc signing by default.
codesign --force --sign "${MICPAUSE_SIGN_IDENTITY:--}" --identifier com.micpause.app "$APP"
codesign --verify --strict "$APP"
echo "应用已打包：$APP"
