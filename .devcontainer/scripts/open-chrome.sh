#!/usr/bin/env bash
# 在远程桌面里打开 Chrome；Chrome 已在运行时只会新增一个标签页
# 用法：open-chrome.sh [URL]
set -uo pipefail

# shellcheck source=./common.sh
# 软链接调用（rd-start 等）时 dirname 会得到 /usr/local/bin，必须 readlink 到真实路径
_rd_self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
source "$(cd "$(dirname "$_rd_self")" && pwd)/common.sh"
unset _rd_self

URL="${1:-$START_URL}"
W="${VNC_RESOLUTION%x*}"
H="${VNC_RESOLUTION#*x}"

CHROME_BIN="$(command -v google-chrome-stable || command -v google-chrome || true)"
if [ -z "$CHROME_BIN" ]; then
  echo "未找到 Chrome，请先构建容器镜像" >&2
  exit 1
fi

FLAGS=(
  --no-sandbox
  --disable-dev-shm-usage
  --disable-gpu
  --no-first-run
  --no-default-browser-check
  --disable-features=Translate,OptimizationHints,MediaRouter
  --start-maximized
  --window-size="${W},${H}"
  --user-data-dir="$LOG_DIR/chrome-profile"
)

# 可选：让 Chrome 走指定国家的代理出口（在 Codespaces secret 里设置 PROXY_URL）
if [ -n "$PROXY_URL" ]; then
  FLAGS+=(--proxy-server="$PROXY_URL")
  [ -n "$PROXY_BYPASS" ] && FLAGS+=(--proxy-bypass-list="$PROXY_BYPASS")
fi

export DISPLAY LANG LANGUAGE
nohup "$CHROME_BIN" "${FLAGS[@]}" "$URL" > "$LOG_DIR/chrome.log" 2>&1 &
echo "Chrome 已启动：$URL"
