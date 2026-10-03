#!/usr/bin/env bash
# 每次连接（postAttach）时的自检：桌面任一环掉线就补拉一次。
# 存在的意义：postStart 之后仍可能因为 SIGHUP / OOM / 容器休眠导致服务掉线，
# 这里保证「只要你打开 codespace 的终端，桌面就是可用的」。
set +u

# 软链接调用时 dirname 会得到 /usr/local/bin，必须 readlink 到真实路径
_rd_self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
source "$(cd "$(dirname "$_rd_self")" && pwd)/common.sh"
unset _rd_self

need_restart=0
port_open "$VNC_PORT"    || need_restart=1
port_open "$NOVNC_PORT"  || need_restart=1
pgrep -f "watchdog\.sh"  >/dev/null 2>&1 || need_restart=1

if [ "$need_restart" -eq 0 ]; then
  exit 0
fi

log "检测到远程桌面未完全就绪，自动补拉…"
bash "$SCRIPT_DIR/start-desktop.sh" >/dev/null 2>&1 &
exit 0
