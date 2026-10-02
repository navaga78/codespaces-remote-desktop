#!/usr/bin/env bash
# codespace 首次创建后执行一次：装好快捷方式、桌面图标、命令别名
set -uo pipefail

# shellcheck source=./common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "初始化远程桌面环境"

# 1) 脚本可执行
chmod +x "$SCRIPT_DIR"/*.sh

# 2) 全局命令：rd-start / rd-stop / rd-chrome / rd-ip / rd-info / rd-status
for pair in "start-desktop:rd-start" "open-chrome:rd-chrome" \
            "stop-desktop:rd-stop" "check-ip:rd-ip" "show-info:rd-info" \
            "status:rd-status"; do
  src="${pair%%:*}.sh"
  dst="${pair##*:}"
  sudo ln -sf "$SCRIPT_DIR/$src" "/usr/local/bin/$dst" 2>/dev/null || true
done

# 3) 准备 noVNC 网页目录（放在家目录下，避免权限问题）
if [ ! -d "$WWW_DIR/core" ]; then
  cp -r /usr/share/novnc/. "$WWW_DIR/" 2>/dev/null || true
fi

# 4) 桌面快捷方式
mkdir -p "$HOME/Desktop"
cat > "$HOME/Desktop/Google Chrome.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Comment=浏览器
Exec=rd-chrome https://www.google.com
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
EOF

cat > "$HOME/Desktop/查看本机IP.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=查看本机IP
Comment=查看出口 IP 与国家
Exec=xfce4-terminal -e "bash -c 'rd-ip; read -p 回车关闭'"
Icon=network-workgroup
Terminal=false
Categories=Network;
EOF

cat > "$HOME/Desktop/重启远程桌面.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=重启远程桌面
Comment=重启桌面服务
Exec=rd-start
Icon=system-reboot
Terminal=false
Categories=System;
EOF

chmod +x "$HOME/Desktop"/*.desktop 2>/dev/null || true
mkdir -p "$HOME/.config/xfce4" 2>/dev/null || true

log "初始化完成。桌面启动脚本：rd-start"
