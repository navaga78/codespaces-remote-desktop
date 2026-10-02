#!/usr/bin/env bash
# 查看这台远程电脑当前的出口 IP 与所属国家
set -uo pipefail

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo "------------------------------------------------------"
if [ -n "$PROXY_URL" ]; then
  echo "代理：已启用（$PROXY_URL）"
else
  echo "代理：未启用（出口 IP = Codespaces 机房所在地）"
fi
echo "------------------------------------------------------"

JSON="$(curl -fsS --max-time 15 https://ipinfo.io/json 2>/dev/null || true)"
if [ -z "$JSON" ]; then
  echo "无法获取 IP 信息（网络受限？）"
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("出口 IP   :", d.get("ip"))
print("国家/地区 :", d.get("country"))
print("城市/区域 :", d.get("city"), "/", d.get("region"))
print("运营商    :", d.get("org"))
'
else
  echo "$JSON"
fi
echo "------------------------------------------------------"
