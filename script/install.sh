#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
START=true
case "${1:-}" in
  --no-start) START=false ;;
  "") ;;
  *) echo "用法：bash script/install.sh [--no-start]" >&2; exit 1 ;;
esac
APP_DIR="${MICPAUSE_APP_DIR:-$HOME/Applications/MicPause.app}"
# Preserve the installed location on upgrades, unless explicitly overridden.
if [[ -z "${MICPAUSE_APP_DIR:-}" && ! -d "$APP_DIR" && -d /Applications/MicPause.app ]]; then
  APP_DIR=/Applications/MicPause.app
fi
[[ "$APP_DIR" = /* && "$(basename "$APP_DIR")" = MicPause.app ]] || { echo "安装目录必须是绝对路径，且以 MicPause.app 结尾。" >&2; exit 1; }
[[ -x "$ROOT/build/MicPause" ]] || { echo "请先运行 bash script/build.sh，或直接运行 bash script/setup.sh。" >&2; exit 1; }
bash "$ROOT/script/package.sh"
mkdir -p "$(dirname "$APP_DIR")"
if [[ ! -w "$(dirname "$APP_DIR")" ]]; then
  echo "没有写入 $APP_DIR 的权限。请用 MICPAUSE_APP_DIR=\"\$HOME/Applications/MicPause.app\" bash script/install.sh 安装到自己的目录。" >&2
  exit 1
fi
# Stop only this user's process with the exact executable name before replacing its bundle.
if [[ -d "$APP_DIR" ]]; then
  pkill -u "$(id -u)" -x MicPause 2>/dev/null || true
  sleep 0.5
fi
ditto "$ROOT/build/MicPause.app" "$APP_DIR"
codesign --verify --strict "$APP_DIR"
if [[ "$START" = true ]]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR"
fi
echo "已安装：$APP_DIR"
echo "请在隐私与安全（辅助功能 / 设备控制和数据访问）中允许这个 MicPause，授权后退出并重新打开。"
if [[ "$START" = true ]]; then
  open "$APP_DIR"
else
  echo "本次未启动应用。"
fi
