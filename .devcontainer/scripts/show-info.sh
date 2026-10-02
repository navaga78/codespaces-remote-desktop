#!/usr/bin/env bash
# 打印远程桌面的访问地址（每次连接 codespace 时自动执行）
set -uo pipefail

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

URL="$(desktop_url)"
{
  echo ""
  echo "  🖥️  云端远程电脑桌面"
  echo "  ───────────────────────────────────────────────"
  if [ -n "$URL" ]; then
    echo "  浏览器打开：$URL"
    echo "  （VS Code 的「端口/PORTS」面板里也能看到 6080）"
  else
    echo "  本地访问：http://localhost:${NOVNC_PORT}"
  fi
  echo "  分辨率：${VNC_RESOLUTION}   语言：${DESKTOP_LANG}"
  echo ""
  echo "  常用命令："
  echo "    rd-start      重启远程桌面"
  echo "    rd-stop       停止远程桌面"
  echo "    rd-chrome URL 在桌面上打开网页"
  echo "    rd-ip         查看当前出口 IP 与所属国家"
  echo "  ───────────────────────────────────────────────"
  echo ""
} | tee -a "$LOG_FILE"
