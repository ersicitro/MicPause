#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "MicPause 仅支持 macOS（面向 MacBook）。" >&2
  exit 1
fi
if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "请先运行 xcode-select --install，在系统窗口中完成安装，再重新运行。" >&2
  exit 1
fi
mkdir -p "$BUILD/module-cache"
FLAGS=(-O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$BUILD/module-cache"
  -debug-prefix-map "$ROOT=." -framework CoreAudio -framework CoreFoundation
  -framework AppKit -framework ApplicationServices -framework ServiceManagement)
echo "编译诊断工具 micprobe …"
xcrun swiftc "${FLAGS[@]}" -o "$BUILD/micprobe" "$ROOT"/Sources/Shared/*.swift "$ROOT/Sources/Probe/main.swift"
echo "编译 MicPause …"
xcrun swiftc "${FLAGS[@]}" -o "$BUILD/MicPause" "$ROOT"/Sources/Shared/*.swift "$ROOT"/Sources/Daemon/*.swift
echo "编译成功。下一步：bash script/install.sh"
