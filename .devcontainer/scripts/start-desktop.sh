#!/usr/bin/env bash
# 启动云端远程电脑桌面：Xvfb -> XFCE -> x11vnc -> noVNC -> Chrome
# 每次 codespace 启动/重启都会自动执行（devcontainer postStartCommand）
# 关键步骤都会有验证，任一步失败都会在终端明显打印，方便排查。
set +e  # 重要：每一步都自己检测失败并继续，让用户能看到完整日志

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "==================== 启动远程桌面 ===================="

# ---- 0. 清理上一次的进程 ----
pkill -f "websockify .*${NOVNC_PORT}" >/dev/null 2>&1
pkill -f "x11vnc"                     >/dev/null 2>&1
pkill -f "xfce4-session|startxfce4|xfwm4|xfce4-panel|xfsettingsd|xfce4-terminal" >/dev/null 2>&1
pkill -f "Xvfb ${DISPLAY}"            >/dev/null 2>&1
sleep 1

DISPLAY_NUM="${DISPLAY#:}"
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

# ---- 1. 虚拟屏幕 Xvfb ----
log "[1/5] 启动虚拟屏幕 Xvfb ${DISPLAY} (${VNC_RESOLUTION})"
nohup Xvfb "${DISPLAY}" -screen 0 "${VNC_RESOLUTION}x24" -nolisten tcp -ac \
      +extension RANDR +extension GLX +extension RENDER \
      > "$LOG_DIR/xvfb.log" 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 40); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    log "  Xvfb 就绪 (pid=${XVFB_PID})"
    break
  fi
  sleep 1
done
if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
  log "✗ Xvfb 启动失败（等了 40s），详情见 $LOG_DIR/xvfb.log"
  tail -30 "$LOG_DIR/xvfb.log"
  exit 1
fi

# ---- 2. XFCE 桌面 ----
log "[2/5] 启动 XFCE 桌面"
export DISPLAY="${DISPLAY}"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE

# 优先 dbus-run-session；它在 dbus 退出会顺手清理 XFCE，更稳
if command -v dbus-run-session >/dev/null 2>&1; then
  if command -v startxfce4 >/dev/null 2>&1; then
    nohup dbus-run-session -- startxfce4 > "$LOG_DIR/xfce.log" 2>&1 &
  elif command -v xfce4-session >/dev/null 2>&1; then
    nohup dbus-run-session -- xfce4-session > "$LOG_DIR/xfce.log" 2>&1 &
  else
    nohup dbus-run-session -- xfwm4 > "$LOG_DIR/xfce.log" 2>&1 &
  fi
else
  nohup startxfce4 > "$LOG_DIR/xfce.log" 2>&1 &
fi
XFCE_PID=$!
log "  XFCE 已 fork (pid=${XFCE_PID})，等待 5s 让窗口管理器起来…"
sleep 5

# 关屏保/休眠，避免长时间不动后黑屏
xset -display "${DISPLAY}" s off -dpms s noblank >/dev/null 2>&1 || true

# ---- 3. 中文输入法（可选）----
if command -v fcitx >/dev/null 2>&1 && ! pgrep -x fcitx >/dev/null 2>&1; then
  nohup env DISPLAY="${DISPLAY}" fcitx -d > "$LOG_DIR/fcitx.log" 2>&1 &
fi

# ---- 4. x11vnc ----
log "[4/5] 启动 x11vnc (端口 ${VNC_PORT})"
VNC_ARGS=(-display "${DISPLAY}" -forever -shared -repeat -noxdamage \
          -rfbport "${VNC_PORT}" -o "$LOG_DIR/x11vnc.log")
if [ -n "$VNC_PASSWORD" ]; then
  mkdir -p "$HOME/.vnc"
  x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null 2>&1
  VNC_ARGS+=(-rfbauth "$HOME/.vnc/passwd")
else
  VNC_ARGS+=(-nopw)
fi
nohup x11vnc "${VNC_ARGS[@]}" > "$LOG_DIR/x11vnc.out" 2>&1 &
VNC_PID=$!

# 等 x11vnc 监听 5900
for _ in $(seq 1 30); do
  if port_open "${VNC_PORT}"; then
    log "  x11vnc 已监听 ${VNC_PORT} (pid=${VNC_PID})"
    break
  fi
  sleep 1
done
if ! port_open "${VNC_PORT}"; then
  log "✗ x11vnc 没起来，看 $LOG_DIR/x11vnc.log："
  tail -30 "$LOG_DIR/x11vnc.log" 2>/dev/null
  log "  继续启动 noVNC，但连上去会失败…"
fi

# ---- 5. noVNC（网页版，端口 6080）----
log "[5/5] 启动 noVNC (端口 ${NOVNC_PORT})"
write_novnc_index
# 注意：--web 必须是绝对路径（~ 不会在 --web=~/x 里被展开，会导致 websockify 退出码 1）
# 也不用 --log-file（部分 websockify 版本不支持），直接重定向输出到日志
if command -v websockify >/dev/null 2>&1; then
  nohup websockify --web="$WWW_DIR" --heartbeat=30 \
        "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
        >> "$LOG_DIR/websockify.log" 2>&1 &
  WS_PID=$!
else
  nohup python3 -m websockify --web="$WWW_DIR" --heartbeat=30 \
        "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
        >> "$LOG_DIR/websockify.log" 2>&1 &
  WS_PID=$!
fi

for _ in $(seq 1 30); do
  if port_open "${NOVNC_PORT}"; then
    log "  noVNC 已监听 ${NOVNC_PORT} (pid=${WS_PID})"
    break
  fi
  sleep 1
done
if ! port_open "${NOVNC_PORT}"; then
  log "  ⚠ 第一次启动没起来，日志："
  tail -20 "$LOG_DIR/websockify.log" 2>/dev/null
  log "  用最简参数再试一次…"
  nohup websockify "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
        >> "$LOG_DIR/websockify.log" 2>&1 &
  WS_PID=$!
  for _ in $(seq 1 20); do
    port_open "${NOVNC_PORT}" && break
    sleep 1
  done
fi
if port_open "${NOVNC_PORT}"; then
  log "  ✓ noVNC 已监听 ${NOVNC_PORT}"
else
  log "✗ noVNC 仍未监听 ${NOVNC_PORT}，看 $LOG_DIR/websockify.log："
  tail -30 "$LOG_DIR/websockify.log" 2>/dev/null
fi

# ---- 6. 自动打开 Chrome ----
if [ "$AUTO_OPEN_CHROME" = "true" ]; then
  bash "$SCRIPT_DIR/open-chrome.sh" "$START_URL" || log "（Chrome 启动失败，可忽略，不影响远程桌面）"
fi

# ---- 总结 ----
log "==================== 远程桌面启动完成 ===================="
log "  noVNC URL : http://localhost:${NOVNC_PORT}"
url="$(desktop_url)"; [ -n "$url" ] && log "  对外 URL  : ${url}"
log "  排查      : cat ~/.remote-desktop/start.log"
log "=========================================================="

exit 0
