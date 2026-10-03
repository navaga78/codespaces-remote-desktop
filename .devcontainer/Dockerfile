# ---------------------------------------------------------------
# 云端远程电脑桌面：XFCE + Chrome + noVNC（跑在 GitHub Codespaces 上）
# 端口 6080 = 网页版远程桌面，直接用浏览器打开即可
# ---------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    DISPLAY=:1 \
    TZ=UTC

# 1) 系统基础 + 中文环境
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        locales \
        language-pack-zh-hans \
        tzdata \
        dbus dbus-x11 \
        ca-certificates curl wget gnupg \
        net-tools iproute2 dnsutils \
        unzip \
    && locale-gen zh_CN.UTF-8 en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# 2) 桌面环境（XFCE）+ 字体 + 中文输入法
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xfce4 xfce4-goodies xfce4-terminal xfce4-screenshooter \
        xauth x11-utils x11-xserver-utils x11-apps xclip \
        fonts-noto fonts-noto-cjk fonts-wqy-zenhei fonts-liberation \
        fcitx fcitx-googlepinyin fcitx-config-gtk im-config \
    && rm -rf /var/lib/apt/lists/*

# 3) 远程桌面服务：Xvfb 虚拟屏 + x11vnc
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 4) noVNC：用上游最新稳定版（apt 里的版本太旧，浏览器兼容性差）
ENV NOVNC_VERSION=1.7.0
RUN set -e; \
    if curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" -o /tmp/novnc.tgz \
       && tar -xzf /tmp/novnc.tgz -C /opt \
       && mv "/opt/noVNC-${NOVNC_VERSION}" /opt/novnc; then \
         rm -f /tmp/novnc.tgz; echo "noVNC ${NOVNC_VERSION} 安装到 /opt/novnc"; \
    else \
         rm -f /tmp/novnc.tgz; echo "noVNC 下载失败，回退 apt 版"; \
         apt-get update && apt-get install -y --no-install-recommends novnc \
         && rm -rf /var/lib/apt/lists/*; \
    fi

# 5) websockify：必须用 pip 最新版
#    Ubuntu 22.04 自带的 0.10.x 有 WebSocket 升级 bug：把握手原样转发给 x11vnc，
#    表现为「noVNC 页面能打开，但点连接提示无法连接」。这个坑必须在这里解决掉。
RUN set -e; \
    if pip3 install --no-cache-dir -U websockify; then \
        echo "websockify(pip) OK"; \
    elif pip3 install --no-cache-dir -U --break-system-packages websockify; then \
        echo "websockify(pip --break-system-packages) OK"; \
    else \
        echo "pip 失败，回退 apt 版（可能连不上，建议手动 pip 升级）"; \
        apt-get update && apt-get install -y --no-install-recommends websockify \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# 6) Google Chrome（稳定版）
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# 7) 中文输入法环境变量（fcitx）
RUN printf '%s\n' \
    'GTK_IM_MODULE=fcitx' \
    'QT_IM_MODULE=fcitx' \
    'XMODIFIERS=@im=fcitx' \
    'DefaultIMModule=fcitx' \
    >> /etc/environment

# 8) 构建期自检：确认关键组件都在（缺了就让构建失败，避免开出来连不上）
RUN websockify --help >/dev/null 2>&1 || python3 -m websockify --help >/dev/null 2>&1 \
    ; ls /opt/novnc/vnc.html >/dev/null 2>&1 || ls /usr/share/novnc/vnc.html >/dev/null 2>&1 \
    ; echo "构建自检完成"

WORKDIR /workspaces
