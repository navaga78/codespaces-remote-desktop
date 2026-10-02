#!/usr/bin/env bash
# 启动云端远程电脑桌面：Xvfb -> XFCE -> x11vnc -> noVNC -> Chrome
# 每次 codespace 启动/重启都会自动执行（devcontainer postStartCommand）
set -uo pipefail

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "==================== 启动远程桌面 ===================="

# ---- 0. 清理上一次的进程 ----
pkill -f "websockify .*${NOVNC_PORT}" >/dev/null 2>&1
pkill -f "x11vnc"                     >/dev/null 2>&1
pkill -f "xfce4-session|startxfce4|xfwm4|xfce4-panel" >/dev/null 2>&1
pkill -f "Xvfb ${DISPLAY}"            >/dev/null 2>&1
sleep 1

DISPLAY_NUM="${DISPLAY#:}"
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

# ---- 1. 虚拟屏幕 Xvfb ----
log "启动虚拟屏幕 Xvfb ${DISPLAY} (${VNC_RESOLUTION})"
nohup Xvfb "${DISPLAY}" -screen 0 "${VNC_RESOLUTION}x24" -nolisten tcp -ac \
      > "$LOG_DIR/xvfb.log" 2>&1 &
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
  log "错误：Xvfb 启动失败，详情见 $LOG_DIR/xvfb.log"
  exit 1
fi

# ---- 2. XFCE 桌面 ----
log "启动 XFCE 桌面"
if command -v startxfce4 >/dev/null 2>&1; then
  nohup env DISPLAY="${DISPLAY}" dbus-launch --exit-with-session startxfce4 \
        > "$LOG_DIR/xfce.log" 2>&1 &
elif command -v xfce4-session >/dev/null 2>&1; then
  nohup env DISPLAY="${DISPLAY}" dbus-launch --exit-with-session xfce4-session \
        > "$LOG_DIR/xfce.log" 2>&1 &
else
  nohup env DISPLAY="${DISPLAY}" xfwm4 > "$LOG_DIR/xfce.log" 2>&1 &
fi
sleep 4

# 关屏保/休眠，避免长时间不动后黑屏
xset -display "${DISPLAY}" s off -dpms s noblank >/dev/null 2>&1 || true

# ---- 3. 中文输入法 ----
if command -v fcitx >/dev/null 2>&1 && ! pgrep -x fcitx >/dev/null 2>&1; then
  nohup env DISPLAY="${DISPLAY}" fcitx -d > "$LOG_DIR/fcitx.log" 2>&1 &
fi

# ---- 4. x11vnc ----
log "启动 x11vnc (端口 ${VNC_PORT})"
VNC_ARGS=(-display "${DISPLAY}" -forever -shared -repeat -rfbport "${VNC_PORT}"
          -o "$LOG_DIR/x11vnc.log")
if [ -n "$VNC_PASSWORD" ]; then
  mkdir -p "$HOME/.vnc"
  x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null 2>&1
  VNC_ARGS+=(-rfbauth "$HOME/.vnc/passwd")
else
  VNC_ARGS+=(-nopw)
fi
nohup x11vnc "${VNC_ARGS[@]}" > "$LOG_DIR/x11vnc.out" 2>&1 &

# ---- 5. noVNC（网页版，端口 6080）----
log "启动 noVNC (端口 ${NOVNC_PORT})"
write_novnc_index
nohup websockify --web="$WWW_DIR" --heartbeat=30 "${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
      > "$LOG_DIR/websockify.log" 2>&1 &

for _ in $(seq 1 30); do
  if port_open "${NOVNC_PORT}"; then break; fi
  sleep 1
done
if port_open "${NOVNC_PORT}"; then
  log "远程桌面已就绪：http://localhost:${NOVNC_PORT}"
else
  log "警告：${NOVNC_PORT} 端口暂未监听，详情见 $LOG_DIR/websockify.log"
fi

# ---- 6. 自动打开 Chrome ----
if [ "$AUTO_OPEN_CHROME" = "true" ]; then
  bash "$SCRIPT_DIR/open-chrome.sh" "$START_URL"
fi

log "==================== 完成 ===================="
exit 0
