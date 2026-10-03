# ☁️ codespaces-remote-desktop

[简体中文](README.md) · English

[![Build desktop image](https://github.com/navaga78/codespaces-remote-desktop/actions/workflows/build-image.yml/badge.svg)](https://github.com/navaga78/codespaces-remote-desktop/actions/workflows/build-image.yml)

Spin up a **full remote Linux desktop with Chrome**, running on **GitHub Codespaces' free compute** — no
software to install, no server of your own. **Pick a country → click once → a complete desktop appears in
your browser with Chrome already open.**

The machine runs inside a GitHub datacenter, so its **public IP is located in the country/region you picked.**

> ⚡ **It starts fast**: the desktop image is prebuilt and published to the public GHCR
> (`ghcr.io/navaga78/codespaces-remote-desktop:latest`) and rebuilt weekly. `devcontainer.json` reuses its
> layers via `cacheFrom`, so the **first launch usually takes 30 seconds to 2 minutes**, and every later
> launch takes a few seconds. If the cache can't be pulled (it only logs a warning), the image is built from
> the Dockerfile as usual — it never fails.

---

## 🚀 Quick start (3 steps)

### 1. Fork this repo to your own GitHub account

Click **Fork** at the top right (so the compute is billed against your own Codespaces quota and you can tweak
the config freely).

### 2. Click a "country button"

Each button carries the datacenter region parameter, so GitHub creates the machine in that country/region.
These are **relative links**, so **you don't need to change anything after forking**.

| Desired IP location | Button | Codespaces region |
| :--- | :---: | :--- |
| 🇺🇸 **United States** (West · Washington) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=WestUs2) | `WestUs2` |
| 🇺🇸 **United States** (East · Virginia) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=EastUs) | `EastUs` |
| 🇳🇱 **Western Europe** (Netherlands · Amsterdam) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=WestEurope) | `WestEurope` |
| 🇸🇬 **Southeast Asia** (Singapore) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](../../../../codespaces/new?ref=main&location=SouthEastAsia) | `SouthEastAsia` |

If GitHub asks which repository to use, pick your fork (the region is already pre-selected).

**Want true one-click?** Paste this into a terminal (change `WestUs2` to the country you want; your username is
detected automatically):

```bash
gh codespace create -R "$(gh api user --jq .login)/codespaces-remote-desktop" -l WestUs2 -w
```

`-l` accepts: `WestUs2` (US West) · `EastUs` (US East) · `WestEurope` (Netherlands) · `SouthEastAsia` (Singapore).

### 3. Wait a few seconds, then open the desktop

Image layers are prebuilt, so it usually takes **30 seconds to 2 minutes** (up to ~4 minutes if no cache is
hit at all). When it's ready:

1. Open the **PORTS** panel in VS Code → find **6080**
2. Click the 🌐 globe icon (or visit `https://<your-codespace-name>-6080.app.github.dev`)
3. A **Linux desktop** appears with Chrome already open, showing your current exit IP and country

🎉 You now have a remote computer whose IP is in the US / Europe / Singapore.

---

## 🌍 About "IP country": two modes

### Mode A — pick a datacenter (default, free, zero config)

The Codespaces VM runs in the region you chose, so the exit IP is in that country/region.
**Limitation:** GitHub currently exposes only 4 regions, so there is **no dedicated UK, Japan or Germany
region**.

> ⚠️ `WestEurope` is located in the **Netherlands**, so the IP geolocates as Netherlands, not United Kingdom.

### Mode B — any country (UK / Japan / Germany / France…) — use a proxy

1. Go to <https://github.com/settings/codespaces> → **Secrets** → **New secret**
2. Name it `PROXY_URL`, value = your proxy endpoint, e.g.
   - `http://user:password@uk.proxy.example.com:8000`
   - `socks5://user:password@jp.proxy.example.com:1080`

   (Most residential proxy providers offer per-country entry nodes, e.g. `uk.host.com:10001`.)
3. **Rebuild** the codespace (secrets only apply after a rebuild)
4. Chrome now exits through that country. Run `rd-ip` or open <https://ipinfo.io/json> to verify.

> Note: the proxy affects Chrome (and anything reading `http_proxy`), not the machine's system-level IP.
> Add `http_proxy` / `https_proxy` secrets too if you need system-wide proxying.

---

## 🧰 Commands (in the codespace terminal)

| Command | What it does |
| :--- | :--- |
| `rd-start` | Restart the remote desktop |
| `rd-stop` | Stop the desktop (codespace keeps running) |
| `rd-chrome https://example.com` | Open a URL on the remote desktop |
| `rd-ip` | Show the current exit IP and country |
| `rd-status` | Ports + processes + logs (**run this first when debugging**) |
| `rd-fix` | Self-check and restart anything that dropped (lighter than `rd-start`) |
| `rd-info` | Print the desktop URL |

Optional Codespaces secrets:

| Secret | Purpose | Default |
| :--- | :--- | :--- |
| `VNC_RESOLUTION` | Screen resolution | `1600x900` |
| `DESKTOP_LANG` | UI language | `zh_CN.UTF-8` |
| `START_URL` | Page Chrome opens on start | `https://ipinfo.io/json` |
| `VNC_PASSWORD` | VNC password (recommended) | empty |
| `PROXY_URL` | Proxy for a specific country exit | empty |

---

## ❓ FAQ

**Q: Why is there still a wait if the image is prebuilt?**
Only the **build layers** are cached. Codespaces still has to provision a VM, attach storage and run
`postStartCommand` to bring up the desktop. With cache: 30s–2min. Without cache (e.g. the upstream image is
unavailable): a full build from the Dockerfile, ~4 minutes.

**Q: noVNC page loads but "cannot connect to server"?**
Run `rd-status` first and check which port is down:

- **6080 not listening** → the page wouldn't load at all; run `rd-start`.
- **6080 listening, 5900 not** → the page opens but the desktop won't connect. If the log shows
  `caught signal: 1` (SIGHUP), the parent shell of the startup script took x11vnc down with it.
  This repo fixes that with **`setsid` (detach from the session)** plus a **watchdog that heals every 5 s**.
  If you forked an older revision, **Sync fork → Rebuild container** first.
- The image also ships noVNC 1.7.0 + the latest pip `websockify` (Ubuntu's 0.10.x has a WebSocket upgrade bug).

The startup script self-tests the WebSocket handshake and prints `✓ WebSocket handshake OK` — the expected
status code is `101`. Logs live in `~/.remote-desktop/`.

**Q: Can the desktop drop while I'm away?**
Not for long. `watchdog.sh` checks Xvfb / XFCE / x11vnc / websockify every 5 seconds and restarts whatever
died; `rd-status` shows `Watchdog: ✓ running`. `rd-stop` writes a `STOPPED` flag first, so it never fights
with the watchdog.

**Q: Does the public GHCR image leak my privacy?**
No. The image contains exactly what the Dockerfile lists (already public in this repo). It contains **no**
passwords, tokens, SSH keys, browser data or home-directory files — the build runs on an ephemeral GitHub
runner using only repository content. Everything you create at runtime stays in the container's writable
layer and is never pushed.

**Q: I don't want to use the upstream GHCR image.**
Remove the `cacheFrom` line from `.devcontainer/devcontainer.json`; it will build from the Dockerfile locally
(slower, but fully self-contained).

**Q: How much free compute do I get?**
Free accounts get **120 core-hours/month** (~60 hours on a 2-core machine; halved on 4-core). Set a spending
limit at <https://github.com/settings/billing>.

**Q: Does the machine survive closing the browser?**
Yes. After **30 minutes idle** the codespace sleeps (data is kept) and the desktop restarts automatically
when you come back.

**Q: Can I use it from a phone or tablet?**
Yes — open `https://<codespace-name>-6080.app.github.dev` in the mobile browser (noVNC supports touch).

**Q: Can I install other software?**
Yes, it's a full Ubuntu 22.04: `sudo apt-get install …`. To bake it into the image, edit
`.devcontainer/Dockerfile` and rebuild.

**Q: Chinese input?**
Built in: fcitx + Google Pinyin, toggle with `Ctrl + Space`.

**Q: Will this get my account banned?**
Follow the [GitHub Acceptable Use Policies](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies).
Don't use it for mining, spam, attacks or abusive scraping.

---

## 🔒 Security

- Port 6080 is **private** by default: only you (logged into GitHub) can reach it. **Don't** flip it to Public.
- Set `VNC_PASSWORD`.
- Chrome keeps your login state — stop or delete the codespace when you're done.

---

## 🧩 How it works

```
Browser ──HTTPS──> noVNC(6080) ──> websockify ──> x11vnc(5900) ──> Xvfb :1
                                                                    │
                                                              XFCE desktop + Chrome
```

- `.devcontainer/Dockerfile`: Ubuntu 22.04 + XFCE + x11vnc + **noVNC 1.7.0** + **latest pip websockify** + Google Chrome + CJK fonts/IME
- `.devcontainer/devcontainer.json`: forwards port 6080, runs `start-desktop.sh` on every start, and reuses the prebuilt GHCR image layers via `cacheFrom`
- `.devcontainer/scripts/start-desktop.sh`: starts Xvfb → XFCE → x11vnc → noVNC → Chrome, with a readiness check per step and a WebSocket handshake self-test (must be `101`). Every background process is launched with `setsid` so the SIGHUP sent when `postStart` finishes cannot kill it
- `.devcontainer/scripts/watchdog.sh`: watchdog that checks Xvfb / XFCE / x11vnc / websockify every 5 s and restarts anything that died
- `.devcontainer/scripts/ensure-desktop.sh`: self-check on every attach (`rd-fix`); restarts missing services in the background
- `.github/workflows/build-image.yml`: builds and pushes the image to GHCR every Monday 03:17 UTC (and whenever `.devcontainer` changes), using `type=inline` cache metadata so forks can hit the cache too
- The region comes from the `location` parameter used when creating the codespace

## 📁 Layout

```
.
├── .devcontainer/
│   ├── devcontainer.json        # ports, env, lifecycle scripts, cacheFrom
│   ├── Dockerfile               # desktop image
│   └── scripts/
│       ├── common.sh            # shared vars (incl. rd-* symlink resolution)
│       ├── post-create.sh       # shortcuts / desktop icons
│       ├── start-desktop.sh     # starts the desktop on every codespace start
│       ├── watchdog.sh          # watchdog: check every 5s, restart on failure
│       ├── ensure-desktop.sh    # rd-fix: self-check + repair on attach
│       ├── stop-desktop.sh      # rd-stop: stops the desktop (and the watchdog)
│       ├── open-chrome.sh
│       ├── check-ip.sh          # show exit IP and country
│       ├── status.sh            # rd-status: ports/processes/logs
│       └── show-info.sh         # print the desktop URL
├── .github/workflows/
│   └── build-image.yml          # weekly image build → GHCR
├── README.md
├── README.en.md
└── LICENSE
```

## 📄 License

MIT — fork and modify freely.
