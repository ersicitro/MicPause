#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/script/build.sh"
bash "$ROOT/script/build-dictation.sh"
bash "$ROOT/script/install.sh" "$@"
bash "$ROOT/script/install-dictation.sh" "$@"
echo "整套工具已安装。请继续完成 README 中的两组快捷键和两个 App 的系统权限，再做一次真实听写测试。"
