#!/usr/bin/env bash
# 停止远程桌面（不会关闭 codespace 本身）
set +u

# 解析真实脚本目录（rd-stop 是 /usr/local/bin 下的软链接，必须 readlink）
_rd_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" 2>/dev/null && pwd)"
if [ -f "$_rd_dir/common.sh" ]; then . "$_rd_dir/common.sh"; fi
unset _rd_dir

: "${DISPLAY:=:1}" "${NOVNC_PORT:=6080}" "${HOME:=/home/vscode}"
: "${LOG_DIR:=$HOME/.remote-desktop}"

# 关键：先放 STOPPED 标志，否则守护进程 5 秒内又把桌面拉起来
touch "$LOG_DIR/STOPPED"
pkill -9 -f "watchdog.sh" >/dev/null 2>&1
sleep 1

pkill -9 -f "websockify" >/dev/null 2>&1
pkill -9 -f "x11vnc"     >/dev/null 2>&1
pkill -9 -f "xfce4-session|startxfce4|xfwm4|xfce4-panel|xfdesktop" >/dev/null 2>&1
pkill -9 -f "google-chrome" >/dev/null 2>&1
pkill -9 -f "Xvfb ${DISPLAY}" >/dev/null 2>&1
sleep 1

echo "已停止远程桌面（含守护进程）。"
echo "想重新启动：rd-start   或   bash .devcontainer/scripts/start-desktop.sh"
