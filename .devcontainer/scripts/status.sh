#!/usr/bin/env bash
# 查看远程桌面相关服务的状态（端口 + 关键进程）
set -uo pipefail
# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo "──────────── 进程 ────────────"
ps -ef | grep -E "Xvfb |x11vnc|websockify|startxfce4|xfwm4|xfce4-panel|xfsettingsd|google-chrome|fcitx" \
   | grep -v grep | awk '{printf "%-7s %s\n", $2, substr($0, index($0,$8))}' || echo "（无）"
echo
echo "──────────── 端口 ────────────"
for p in "${VNC_PORT}" "${NOVNC_PORT}"; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1; then
    echo "  127.0.0.1:$p   ✓ 监听中"
  else
    echo "  127.0.0.1:$p   ✗ 未监听"
  fi
done
echo
echo "──────────── URL ────────────"
url="$(desktop_url)"
if [ -n "$url" ]; then
  echo "  远程桌面：$url"
fi
echo
echo "──────────── 最近日志 ────────────"
for f in start.log xvfb.log xfce.log x11vnc.log x11vnc.out websockify.log websockify.out chrome.log; do
  if [ -s "$LOG_DIR/$f" ]; then
    echo "─── $f (tail -15) ───"
    tail -15 "$LOG_DIR/$f"
    echo
  fi
done
echo "完整日志在：$LOG_DIR"
