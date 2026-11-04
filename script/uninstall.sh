#!/bin/bash
set -euo pipefail
APP_DIR="${MICPAUSE_APP_DIR:-$HOME/Applications/MicPause.app}"
if [[ -z "${MICPAUSE_APP_DIR:-}" && ! -d "$APP_DIR" && -d /Applications/MicPause.app ]]; then
  APP_DIR=/Applications/MicPause.app
fi
[[ "$APP_DIR" = /* && "$(basename "$APP_DIR")" = MicPause.app ]] || { echo "无效的 MicPause 安装目录。" >&2; exit 1; }
echo "请先从 MicPause 菜单关闭开机自启；若仍有登录项，请在系统设置 → 通用 → 登录项中移除。"
pkill -u "$(id -u)" -x MicPause 2>/dev/null || true
sleep 0.3
if [[ -d "$APP_DIR" ]]; then rm -rf -- "$APP_DIR"; fi
echo "MicPause 已移除；本地配置和日志仍保留，避免误删你的设置。"
