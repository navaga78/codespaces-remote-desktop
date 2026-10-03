#!/usr/bin/env bash
# 启动云端远程电脑桌面：Xvfb -> XFCE -> x11vnc -> noVNC -> Chrome
# 每次 codespace 启动/重启都会自动执行（devcontainer postStartCommand）
# 关键步骤都会有验证，任一步失败都会在终端明显打印，方便排查。
set +e  # 重要：每一步都自己检测失败并继续，让用户能看到完整日志

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "==================== 启动远程桌面 ===================="

# ---- 0. 清理上一次的进程（宁可多杀，避免残留进程占端口）----
pkill -9 -f "websockify" >/dev/null 2>&1
pkill -9 -f "x11vnc"     >/dev/null 2>&1
pkill -9 -f "xfce4-session|startxfce4|xfwm4|xfce4-panel|xfsettingsd|xfdesktop|xfce4-terminal" >/dev/null 2>&1
pkill -9 -f "Xvfb ${DISPLAY}" >/dev/null 2>&1
sleep 1
# 二次确认：还有残留 websockify 就逐个杀
for _p in $(pgrep -f "websockify" 2>/dev/null); do kill -9 "$_p" 2>/dev/null; done
unset _p

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
# 注意 1：--web 必须是绝对路径（~ 不会在 --web=~/x 里被展开，会导致 websockify 退出码 1）
# 注意 2：不要用 --log-file（部分版本不支持），直接重定向到日志
# 注意 3：优先用 pip 装的新版 websockify（Ubuntu 22.04 自带的 0.10.x 有 WS 升级 bug，
#         会把握手原样转发给 x11vnc，表现为「页面能打开但连不上」）
WS_CMD=""
for cand in "$HOME/.local/bin/websockify" "$HOME/.local/bin/ws-websockify" "$(command -v websockify 2>/dev/null)"; do
  if [ -n "$cand" ] && [ -x "$cand" ]; then WS_CMD="$cand"; break; fi
done
[ -z "$WS_CMD" ] && WS_CMD="python3 -m websockify"
log "  使用 websockify: $WS_CMD"

nohup $WS_CMD --web="$WWW_DIR" \
      "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
      >> "$LOG_DIR/websockify.log" 2>&1 &
WS_PID=$!

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

# ---- 5b. WebSocket 升级自检（关键：101 = 正常，其它 = websockify 有问题）----
if command -v curl >/dev/null 2>&1 && port_open "${NOVNC_PORT}"; then
  WS_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "http://127.0.0.1:${NOVNC_PORT}/websockify" 2>/dev/null)"
  log "  WebSocket 握手自检 HTTP ${WS_CODE}"
fi

# ---- 5c. 自检失败时自动升级 websockify 再试一次 ----
if [ "${WS_CODE:-000}" != "101" ] && [ ! -x "$HOME/.local/bin/websockify" ] \
   && command -v pip3 >/dev/null 2>&1; then
  log "  ⚠ 握手没通过，自动 pip 安装新版 websockify 后重试…"
  pip3 install --user -q -U websockify >/dev/null 2>&1 \
    || pip3 install --user -q -U --break-system-packages websockify >/dev/null 2>&1
  if [ -x "$HOME/.local/bin/websockify" ]; then
    pkill -9 -f websockify >/dev/null 2>&1; sleep 1
    nohup "$HOME/.local/bin/websockify" --web="$WWW_DIR" \
          "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
          >> "$LOG_DIR/websockify.log" 2>&1 &
    sleep 3
    WS_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
      "http://127.0.0.1:${NOVNC_PORT}/websockify" 2>/dev/null)"
    log "  换用新版 websockify 后自检 HTTP ${WS_CODE}"
  fi
fi
if [ "${WS_CODE:-000}" = "101" ]; then
  log "  ✓ WebSocket 握手正常，浏览器可以连了"
else
  log "  ✗ WebSocket 握手仍失败 (HTTP ${WS_CODE:-000})，浏览器会连不上；日志：$LOG_DIR/websockify.log"
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
