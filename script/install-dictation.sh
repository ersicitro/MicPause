#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${MICPAUSE_TOOLS_DIR:-$HOME/Applications/MicPause Tools}"
AGENTS="${MICPAUSE_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LABEL=io.micpause.global-dictation
START=true
case "${1:-}" in --no-start) START=false ;; "") ;; *) echo "用法：bash script/install-dictation.sh [--no-start]" >&2; exit 1 ;; esac
[[ "$TOOLS" = /* && "$AGENTS" = /* ]] || { echo "安装路径必须为绝对路径。" >&2; exit 1; }
[[ -d "$ROOT/build/MicPause Tools/ChatGPT 全局听写.app" ]] || { echo "请先运行 bash script/build-dictation.sh" >&2; exit 1; }
mkdir -p "$TOOLS" "$AGENTS"
for NAME in 'ChatGPT 全局听写.app' 'ChatGPT 听写助手.app'; do
  ditto "$ROOT/build/MicPause Tools/$NAME" "$TOOLS/$NAME"
  codesign --verify --strict "$TOOLS/$NAME"
done
# PlistBuddy handles user paths as values; the file is generated locally, never committed.
PLIST="$AGENTS/$LABEL.plist"
if [[ -f "$PLIST" ]]; then rm -- "$PLIST"; fi
/usr/libexec/PlistBuddy -c "Add :Label string $LABEL" "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments array' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments:0 string /usr/bin/open' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments:1 string -g' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :ProgramArguments:2 string -a' "$PLIST"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:3 string $TOOLS/ChatGPT 全局听写.app" "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :RunAtLoad bool true' "$PLIST"
plutil -lint "$PLIST"
echo "已安装：$TOOLS"
echo "请先按 README 给 ChatGPT 听写助手授权，并设置客户端的两组快捷键。"
if [[ "$START" = true ]]; then open "$TOOLS/ChatGPT 全局听写.app"; else echo "本次未启动工具。"; fi
