#!/usr/bin/env bash
# 公共变量与工具函数，被其它脚本 source 使用
# shellcheck shell=bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"

export DISPLAY="${DISPLAY:-:1}"
VNC_RESOLUTION="${VNC_RESOLUTION:-1600x900}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
START_URL="${START_URL:-https://ipinfo.io/json}"
AUTO_OPEN_CHROME="${AUTO_OPEN_CHROME:-true}"
DESKTOP_LANG="${DESKTOP_LANG:-zh_CN.UTF-8}"
PROXY_URL="${PROXY_URL:-}"
PROXY_BYPASS="${PROXY_BYPASS:-localhost;127.0.0.1;*.github.dev}"

LOG_DIR="${HOME:-/home/vscode}/.remote-desktop"
WWW_DIR="$LOG_DIR/www"
mkdir -p "$LOG_DIR" "$WWW_DIR"
LOG_FILE="$LOG_DIR/start.log"

export LANG="$DESKTOP_LANG"
export LANGUAGE="${DESKTOP_LANG%.*}"
export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

# 端口是否在监听
port_open() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

# noVNC 落地页：打开 6080 时自动跳转并连接
write_novnc_index() {
  if [ ! -d "$WWW_DIR/core" ]; then
    cp -r /usr/share/novnc/. "$WWW_DIR/" 2>/dev/null || true
  fi
  {
    echo '<!doctype html><html><head><meta charset="utf-8">'
    echo '<title>云端远程电脑桌面</title></head><body>'
    echo '<script>'
    echo "var q='autoconnect=true&resize=scale&reconnect=true&reconnect_delay=1000';"
    if [ -n "$VNC_PASSWORD" ]; then
      echo "q += '&password=' + encodeURIComponent('$VNC_PASSWORD');"
    fi
    echo "location.replace('vnc.html?' + q);"
    echo '</script>'
    echo '<noscript><a href="vnc.html">点击进入远程桌面</a></noscript>'
    echo '</body></html>'
  } > "$WWW_DIR/index.html"
}

# 当前 codespace 的桌面访问地址
desktop_url() {
  if [ -n "${CODESPACE_NAME:-}" ]; then
    local domain="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    printf 'https://%s-%s.%s\n' "$CODESPACE_NAME" "$NOVNC_PORT" "$domain"
  fi
}
