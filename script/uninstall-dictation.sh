#!/bin/bash
set -euo pipefail
TOOLS="${MICPAUSE_TOOLS_DIR:-$HOME/Applications/MicPause Tools}"
AGENTS="${MICPAUSE_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LABEL=io.micpause.global-dictation
[[ "$TOOLS" = /* && "$(basename "$TOOLS")" = 'MicPause Tools' && "$AGENTS" = /* ]] || { echo "无效的工具目录。" >&2; exit 1; }
echo "请先用活动监视器退出 GlobalDictationHotkey；若正录音，请先结束录音。"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f -- "$AGENTS/$LABEL.plist"
if [[ -d "$TOOLS" ]]; then rm -rf -- "$TOOLS"; fi
echo "全局听写工具和下次登录启动项已移除。请按需在系统权限中移除旧助手。"
