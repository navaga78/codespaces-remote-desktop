#!/usr/bin/env bash
# 停止远程桌面（不会关闭 codespace 本身）
set -uo pipefail

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "停止远程桌面相关进程"
pkill -f "websockify .*${NOVNC_PORT}" >/dev/null 2>&1
pkill -f "x11vnc"                     >/dev/null 2>&1
pkill -f "xfce4-session|startxfce4|xfwm4|xfce4-panel" >/dev/null 2>&1
pkill -f "google-chrome"              >/dev/null 2>&1
pkill -f "Xvfb ${DISPLAY}"            >/dev/null 2>&1
sleep 1
log "已停止。想重新启动：rd-start 或 bash .devcontainer/scripts/start-desktop.sh"
