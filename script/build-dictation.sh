#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/build/MicPause Tools"
GLOBAL="$TOOLS/ChatGPT 全局听写.app"
HELPER="$TOOLS/ChatGPT 听写助手.app"
[[ "$(uname -s)" = Darwin ]] || { echo "仅支持 MacBook / macOS。" >&2; exit 1; }
mkdir -p "$GLOBAL/Contents/MacOS" "$ROOT/build/module-cache"
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$ROOT/build/module-cache" \
  -debug-prefix-map "$ROOT=." "$ROOT/Sources/Dictation/GlobalDictationHotkey.swift" \
  -o "$GLOBAL/Contents/MacOS/GlobalDictationHotkey"
# Always start from a clean generated helper; never modify an already authorized installed copy in place.
if [[ -d "$HELPER" ]]; then rm -rf -- "$HELPER"; fi
osacompile -o "$HELPER" "$ROOT/Sources/Dictation/DictationHelper.applescript"
# Generate portable bundle metadata, with no developer paths, identity, or bundled keys.
cat > "$GLOBAL/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.micpause.global-dictation</string>
<key>CFBundleName</key><string>ChatGPT 全局听写</string>
<key>CFBundleExecutable</key><string>GlobalDictationHotkey</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string io.micpause.dictation-helper' "$HELPER/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName ChatGPT 听写助手' "$HELPER/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$HELPER/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :NSAppleEventsUsageDescription 将当前聊天置于前台，聚焦输入框并开始或停止听写。' "$HELPER/Contents/Info.plist"
# osacompile adds generic privacy descriptions for unrelated features; remove them.
for key in NSAppleMusicUsageDescription NSCalendarsUsageDescription NSCameraUsageDescription NSContactsUsageDescription NSHomeKitUsageDescription NSMicrophoneUsageDescription NSPhotoLibraryUsageDescription NSRemindersUsageDescription NSSiriUsageDescription NSSystemAdministrationUsageDescription; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$HELPER/Contents/Info.plist" 2>/dev/null || true
done
for APP in "$GLOBAL" "$HELPER"; do
  codesign --force --sign "${MICPAUSE_SIGN_IDENTITY:--}" "$APP"
  codesign --verify --strict "$APP"
done
"$GLOBAL/Contents/MacOS/GlobalDictationHotkey" --self-test
echo "全局听写工具已编译：$TOOLS"
