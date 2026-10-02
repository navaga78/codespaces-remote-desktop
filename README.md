# ☁️ codespaces-remote-desktop

用 **GitHub Codespaces 的免费算力**开一台**带 Chrome 的远程电脑桌面**（Linux XFCE + VNC）。
不用装任何软件、不用自己有服务器：**选好国家 → 点一下按钮 → 浏览器里出现一台完整的电脑桌面，Chrome 已自动打开。**

桌面跑在 GitHub 机房里，它的**公网出口 IP 就在你选的国家/地区**。

---

## 🚀 一键开始（三步）

### 第 1 步：Fork 本仓库到你自己的 GitHub 账号

点右上角 **Fork**（这样算力走的是你自己的 Codespaces 额度，也方便你自己改配置）。

### 第 2 步：点一个「国家按钮」

下面的按钮已经把**机房地区参数**写进链接里，点了之后 GitHub 就会在对应国家/地区的机房给你开一台电脑。
按钮用的是相对链接，所以**你 fork 之后不用改任何东西**，直接点即可。

| 想要的 IP 归属地 | 按钮 | Codespaces 机房 |
| :--- | :---: | :--- |
| 🇺🇸 **美国**（西部 · 华盛顿州） | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=WestUs2) | `WestUs2` |
| 🇺🇸 **美国**（东部 · 弗吉尼亚州） | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=EastUs) | `EastUs` |
| 🇳🇱 **欧洲西部**（荷兰 · 阿姆斯特丹） | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=WestEurope) | `WestEurope` |
| 🇸🇬 **东南亚**（新加坡） | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=SouthEastAsia) | `SouthEastAsia` |

> 打开后如果让你选仓库，选你刚 fork 出来的那个即可（地区已经按按钮预选好了）。

**想要真正的「一步到位」？** 把下面这行粘到终端里（会把 `美国西部` 换成你想要的国家，用户名自动识别）：

```bash
gh codespace create -R "$(gh api user --jq .login)/codespaces-remote-desktop" -l WestUs2 -w
```

`-l` 可选值：`WestUs2`（美西）· `EastUs`（美东）· `WestEurope`（欧洲西部·荷兰）· `SouthEastAsia`（新加坡）。

对应的完整网页链接（把 `你的用户名` 换成你的 GitHub 用户名，例如 `navaga78`）：

```
https://github.com/codespaces/new?hide_repo_select=true&ref=main&location=WestUs2&repo=你的用户名/codespaces-remote-desktop
```

### 第 3 步：等 3~5 分钟，打开桌面

首次启动要构建镜像（约 3~5 分钟，之后再启动只要几秒）。
构建完成后：

1. 在 VS Code 网页版里看 **「端口 / PORTS」** 面板 → 找到 **6080**；
2. 点那一行右边的 🌐 地球图标（或直接访问 `https://<你的codespace名>-6080.app.github.dev`）；
3. 浏览器里就出现一台 **Linux 电脑桌面**，Chrome 已经自动打开，并显示当前的出口 IP 与国家。

🎉 至此你就有了一台「IP 在美国/欧洲/新加坡」的远程电脑。

---

## 🌍 关于「IP 国家」：两种模式

### 模式 A：直接选机房（默认，免费、零配置）

Codespaces 的机器就跑在指定机房，出口 IP 就在那个国家/地区。**优点**：什么都不用配。**限制**：GitHub 目前只开放了 4 个机房区域（美国东部/西部、欧洲西部=荷兰、东南亚=新加坡），**没有英国、日本、德国等单独机房**。

> ⚠️ `WestEurope` 数据中心在**荷兰（阿姆斯特丹）**，所以 IP 会显示 Netherlands，而不是 United Kingdom。

### 模式 B：任意国家（英国 / 日本 / 德国 / 法国…）——配一个代理

想要真正的「英国 IP」，给这台电脑挂一个对应国家的代理即可：

1. 打开 <https://github.com/settings/codespaces> → **Secrets** → **New secret**
2. 名字填 `PROXY_URL`，值填你的代理地址，例如：
   - `http://user:password@uk.proxy.example.com:8000`
   - `socks5://user:password@jp.proxy.example.com:1080`
   （大多数海外代理服务商都提供「按国家切换入口节点」的域名/端口，如 `uk.xxx.com:10001`、`jp.xxx.com:10001`）
3. **重建** codespace（改 secret 后需 rebuild 才生效）
4. 之后 Chrome 会自动通过这个代理上网，桌面里打开 <https://ipinfo.io/json> 或运行 `rd-ip` 就能看到国家已变成英国/日本。

> 提示：代理只影响 Chrome（以及读取 `http_proxy` 的程序）的出口 IP，不影响整台机器的系统级 IP。如果你希望系统级也走代理，可在 secret 里再加 `http_proxy` / `https_proxy`。

---

## 🧰 常用命令（codespace 终端里）

| 命令 | 作用 |
| :--- | :--- |
| `rd-start` | 重启远程桌面（改了配置后用） |
| `rd-stop` | 停止桌面（codespace 本身还在跑） |
| `rd-chrome https://example.com` | 在远程桌面上打开某个网页 |
| `rd-ip` | 查看这台电脑当前的出口 IP 与国家 |
| `rd-info` | 打印桌面访问地址 |

改分辨率 / 语言 / 自动打开的网址：在 <https://github.com/settings/codespaces> 的 Secrets 里加：

| Secret 名 | 说明 | 默认 |
| :--- | :--- | :--- |
| `VNC_RESOLUTION` | 桌面分辨率 | `1600x900` |
| `DESKTOP_LANG` | 界面语言 | `zh_CN.UTF-8` |
| `START_URL` | Chrome 自动打开的页面 | `https://ipinfo.io/json` |
| `VNC_PASSWORD` | 给 VNC 加密码（建议设） | 空 |
| `PROXY_URL` | 指定国家出口的代理 | 空 |

---

## ❓ 常见问题

**Q：免费的 Codespaces 额度够用吗？**
GitHub 免费账号每月有 **120 核时**（2 核机器约 60 小时）；4 核机器减半。用完按小时计费，建议在 <https://github.com/settings/billing> 设一个消费上限。

**Q：关掉浏览器后电脑还在吗？**
在。默认 **30 分钟无操作** codespace 会自动休眠（数据不丢），下次打开会自动重启桌面。可在创建时用 `--idle-timeout` 或在 codespace 设置里调整。

**Q：我在 VS Code 桌面版里怎么用？**
一样：打开的 codespace → 「端口」面板 → 转发 6080 → 右键设为 Public 或直接用浏览器打开转发地址。

**Q：手机 / iPad 能用吗？**
能。用手机浏览器打开 `https://<codespace名>-6080.app.github.dev` 即可（noVNC 支持触摸操作）。

**Q：能装别的软件吗？**
能，这就是一台完整的 Ubuntu 22.04。`sudo apt-get install ...` 随便装；想固化进镜像，改 `.devcontainer/Dockerfile` 后 rebuild。

**Q：能不能中文输入？**
可以，已内置 fcitx + 谷歌拼音，桌面右上角/任务栏切换（默认 `Ctrl + 空格`）。

**Q：会不会被 GitHub 封号？**
请遵守 [GitHub 可接受使用政策](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)。本项目只是把 Codespaces 当成一台普通云主机来跑桌面，**不要**用它做挖矿、 spam、攻击、批量爬取等违反政策的用途。

---

## 🔒 安全提醒

- 6080 端口默认是**私有**的：只有登录你 GitHub 账号的人能访问。**不要随意把端口改成 Public**，否则任何人拿到 URL 都能操控你的桌面。
- 建议设置 `VNC_PASSWORD`。
- 桌面里的 Chrome 会保存登录态，用完记得在 codespace 页面点 **Stop codespace**，或删掉 codespace。

---

## 🧩 工作原理

```
浏览器 ──HTTPS──> noVNC(6080) ──> websockify ──> x11vnc(5900) ──> Xvfb :1
                                                                    │
                                                              XFCE 桌面 + Chrome
```

- `.devcontainer/Dockerfile`：Ubuntu 22.04 + XFCE + x11vnc + noVNC + Google Chrome + 中文字体/输入法
- `.devcontainer/devcontainer.json`：转发 6080 端口，并在每次启动时执行 `start-desktop.sh`
- `.devcontainer/scripts/start-desktop.sh`：拉起 Xvfb → XFCE → x11vnc → noVNC → Chrome
- 机房地区由创建 codespace 时的 `location` 参数决定（`WestUs2` / `EastUs` / `WestEurope` / `SouthEastAsia`）

## 📁 目录结构

```
.
├── .devcontainer/
│   ├── devcontainer.json        # Codespaces 配置（端口、环境变量、启动脚本）
│   ├── Dockerfile               # 桌面镜像
│   └── scripts/
│       ├── common.sh            # 公共变量
│       ├── post-create.sh       # 首次创建：快捷方式 / 桌面图标
│       ├── start-desktop.sh     # 启动桌面（每次 codespace 启动自动执行）
│       ├── stop-desktop.sh
│       ├── open-chrome.sh
│       ├── check-ip.sh          # 查看出口 IP 与国家
│       └── show-info.sh         # 打印桌面访问地址
├── README.md
└── LICENSE
```

## 📄 License

MIT —— 随便 fork、随便改。
