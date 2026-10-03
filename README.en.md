# ☁️ codespaces-remote-desktop

Spin up a **full remote Linux desktop with Chrome**, running on **GitHub Codespaces' free compute** — no
software to install, no server of your own. **Pick a country → click once → a complete desktop appears in
your browser with Chrome already open.**

The machine runs inside a GitHub datacenter, so its **public IP is located in the country/region you picked.**

---

## 🚀 Quick start (3 steps)

### 1. Fork this repo to your own GitHub account

Click **Fork** at the top right (so the compute is billed against your own Codespaces quota and you can tweak
the config freely).

### 2. Click a "country button"

Each button carries the datacenter region parameter, so GitHub creates the machine in that country/region.
These are relative links, so **you don't need to change anything after forking**.

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

### 3. Wait 3–5 minutes, then open the desktop

The first launch builds the image (later launches take seconds). When it's ready:

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

---

## 🧰 Commands (in the codespace terminal)

| Command | What it does |
| :--- | :--- |
| `rd-start` | Restart the remote desktop |
| `rd-stop` | Stop the desktop (codespace keeps running) |
| `rd-chrome https://example.com` | Open a URL on the remote desktop |
| `rd-ip` | Show the current exit IP and country |
| `rd-status` | Processes + ports + all logs (run this first when debugging) |
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

**Q: noVNC page loads but "cannot connect to server"?**
The image already fixes the usual cause (it ships noVNC 1.7.0 + the latest pip `websockify`; Ubuntu's
websockify 0.10.x has a WebSocket upgrade bug). If it still happens, run `rd-status` to see which of
5900/6080 is not listening, then `rd-start`. The startup script self-tests the WebSocket handshake and prints
`✓ WebSocket handshake OK` — the expected status code is `101`.

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
- `.devcontainer/devcontainer.json`: forwards port 6080, runs `start-desktop.sh` on every start, and reuses the prebuilt image from GHCR via `cacheFrom`
- `.github/workflows/build-image.yml`: weekly build of the desktop image to GHCR so forks start fast
- The region comes from the `location` parameter used when creating the codespace

## 📄 License

MIT — fork and modify freely.
