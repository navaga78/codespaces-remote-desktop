#!/usr/bin/env bash
# 守护进程：Xvfb / x11vnc / websockify 任何一环掉线就自动拉起。
# 存在的意义：postStartCommand 的 shell 退出时会发 SIGHUP，
# 而 x11vnc 自己注册了 SIGHUP 处理函数（会覆盖 nohup 的设置），会被杀掉。
# 启动：$RD_SPAWN nohup bash watchdog.sh &
# 停止：touch ~/.remote-desktop/STOPPED（rd-stop 会做），守护进程会自行退出。
set +u

_rd_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" 2>/dev/null && pwd)"
if [ -f "$_rd_dir/common.sh" ]; then . "$_rd_dir/common.sh"; fi
unset _rd_dir

: "${DISPLAY:=:1}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=6080}"
: "${VNC_RESOLUTION:=1600x900}"
: "${VNC_PASSWORD:=}"
: "${HOME:=/home/vscode}"
: "${LOG_DIR:=$HOME/.remote-desktop}"
: "${WWW_DIR:=$LOG_DIR/www}"
: "${NOVNC_SRC:=/opt/novnc}"
mkdir -p "$LOG_DIR" "$WWW_DIR"

STOP_FLAG="$LOG_DIR/STOPPED"
WATCHDOG_LOG="$LOG_DIR/watchdog.log"

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$WATCHDOG_LOG"; }

port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }

ws_cmd() {
  for c in /usr/local/bin/websockify "$HOME/.local/bin/websockify" "$(command -v websockify 2>/dev/null)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; return; fi
  done
  echo "python3 -m websockify"
}

start_xvfb() {
  $RD_SPAWN nohup Xvfb "$DISPLAY" -screen 0 "${VNC_RESOLUTION}x24" -nolisten tcp -ac \
    +extension RANDR +extension GLX +extension RENDER \
    >> "$LOG_DIR/xvfb.log" 2>&1 </dev/null &
}

start_x11vnc() {
  local args=(-display "$DISPLAY" -forever -shared -repeat -noxdamage -rfbport "$VNC_PORT" -o "$LOG_DIR/x11vnc.log")
  if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p "$HOME/.vnc"
    x11vnc -storepasswd "$VNC_PASSWORD" "$HOME/.vnc/passwd" >/dev/null 2>&1
    args+=(-rfbauth "$HOME/.vnc/passwd")
  else
    args+=(-nopw)
  fi
  # setsid：脱离当前会话，收不到 shell 退出时的 SIGHUP
  $RD_SPAWN nohup x11vnc "${args[@]}" >> "$LOG_DIR/x11vnc.out" 2>&1 </dev/null &
}

start_xfce() {
  export DISPLAY XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=XFCE
  if command -v dbus-run-session >/dev/null 2>&1; then
    $RD_SPAWN nohup dbus-run-session -- startxfce4 >> "$LOG_DIR/xfce.log" 2>&1 </dev/null &
  else
    $RD_SPAWN nohup startxfce4 >> "$LOG_DIR/xfce.log" 2>&1 </dev/null &
  fi
}

start_websockify() {
  [ ! -f "$WWW_DIR/vnc.html" ] && cp -r "$NOVNC_SRC"/. "$WWW_DIR/" 2>/dev/null
  command -v write_novnc_index >/dev/null 2>&1 && write_novnc_index
  $RD_SPAWN nohup $(ws_cmd) --web="$WWW_DIR" "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" \
    >> "$LOG_DIR/websockify.log" 2>&1 </dev/null &
}

log "守护进程启动 (pid=$$)"

_tick=0
while true; do
  [ -f "$STOP_FLAG" ] && { log "检测到 STOPPED，退出"; exit 0; }
  sleep 5
  [ -f "$STOP_FLAG" ] && { log "检测到 STOPPED，退出"; exit 0; }
  _tick=$((_tick + 1))

  if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    log "Xvfb 掉线，重新启动"
    start_xvfb
    sleep 3
  fi

  # XFCE 死了桌面是黑屏/无窗口管理器，检测到就补拉一次
  if ! pgrep -f "xfwm4|xfce4-session|startxfce4" >/dev/null 2>&1; then
    log "XFCE 掉线，重新启动"
    start_xfce
    sleep 3
  fi

  if ! port_open "$VNC_PORT"; then
    log "x11vnc 掉线，重新启动"
    start_x11vnc
    sleep 2
  fi

  if ! port_open "$NOVNC_PORT"; then
    log "websockify 掉线，重新启动"
    start_websockify
    sleep 2
  fi

  # 每 10 分钟把日志裁到最近 200 行，避免无限增长
  if [ $((_tick % 120)) -eq 0 ]; then
    tail -200 "$WATCHDOG_LOG" > "$WATCHDOG_LOG.tmp" 2>/dev/null \
      && mv "$WATCHDOG_LOG.tmp" "$WATCHDOG_LOG"
  fi
done
