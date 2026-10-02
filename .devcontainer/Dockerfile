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

# 3) 远程桌面服务：Xvfb 虚拟屏 + x11vnc + noVNC(网页)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        novnc websockify \
    && rm -rf /var/lib/apt/lists/*

# 4) Google Chrome（稳定版）
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# 5) 中文输入法环境变量（fcitx）
RUN printf '%s\n' \
    'GTK_IM_MODULE=fcitx' \
    'QT_IM_MODULE=fcitx' \
    'XMODIFIERS=@im=fcitx' \
    'DefaultIMModule=fcitx' \
    >> /etc/environment

# 6) 工作目录
WORKDIR /workspaces
