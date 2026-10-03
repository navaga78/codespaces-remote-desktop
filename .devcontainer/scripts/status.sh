#!/usr/bin/env bash
# 远程桌面排障首选：进程（去重计数）+ 端口 + WebSocket 握手自检 + 最近日志
set +u

# shellcheck source=./common.sh
_rd_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" 2>/dev/null && pwd)"
if [ -f "$_rd_dir/common.sh" ]; then
  # shellcheck disable=SC1091
  . "$_rd_dir/common.sh"
fi
unset _rd_dir

# 兜底：即使 common.sh 没加载成功（软链接/路径问题），也保证不报「未绑定的变量」
: "${DISPLAY:=:1}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=6080}"
: "${VNC_RESOLUTION:=1600x900}"
: "${DESKTOP_LANG:=zh_CN.UTF-8}"
: "${HOME:=/home/vscode}"
: "${LOG_DIR:=$HOME/.remote-desktop}"
: "${LOG_FILE:=$LOG_DIR/start.log}"

echo "──────────── 进程（去重计数）────────────"
ps -eo args --no-headers 2>/dev/null \
  | grep -E "Xvfb :[0-9]|x11vnc|websockify|startxfce4|xfwm4|xfce4-panel|xfsettingsd|xfdesktop|google-chrome-stable|fcitx" \
  | grep -v grep \
  | sed -E 's/^[[:space:]]+//' \
  | sort | uniq -c | sort -rn \
  | awk '{n=$1; $1=""; printf "  x%-4s%s\n", n, substr($0,2)>180?substr($0,2,180)"…":substr($0,2)}' \
  || echo "  （没有匹配到进程）"

WS_N="$(pgrep -cf websockify 2>/dev/null || echo 0)"
echo
echo "  websockify 进程/线程数：${WS_N}   （数字大是正常的：每路连接会派生一个）"
echo

echo "──────────── 端口 ────────────"
for p in "$VNC_PORT" "$NOVNC_PORT"; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1; then
    echo "  127.0.0.1:$p   ✓ 监听中"
  else
    echo "  127.0.0.1:$p   ✗ 未监听"
  fi
done

echo
echo "──────────── WebSocket 握手自检 ────────────"
if (exec 3<>"/dev/tcp/127.0.0.1/$NOVNC_PORT") >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "http://127.0.0.1:${NOVNC_PORT}/websockify" 2>/dev/null)"
  if [ "$CODE" = "101" ]; then
    echo "  ✓ HTTP ${CODE} —— 正常，浏览器可以连上"
  else
    echo "  ✗ HTTP ${CODE} —— 异常（必须是 101），websockify 没完成 WS 升级"
  fi
else
  echo "  （6080 未监听或无 curl，跳过）"
fi

echo
echo "──────────── 访问地址 ────────────"
if [ -n "${CODESPACE_NAME:-}" ]; then
  echo "  https://${CODESPACE_NAME}-${NOVNC_PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
fi
echo "  分辨率：${VNC_RESOLUTION}   语言：${DESKTOP_LANG}"

echo
echo "──────────── 最近日志 ────────────"
for f in start.log xvfb.log xfce.log x11vnc.log x11vnc.out websockify.log websockify.out chrome.log; do
  if [ -s "$LOG_DIR/$f" ]; then
    echo "─── $f (tail -12) ───"
    tail -12 "$LOG_DIR/$f"
    echo
  fi
done
echo "完整日志目录：$LOG_DIR"
