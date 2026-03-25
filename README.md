# Claude Code on Android

<p align="center">
  <img src="assets/logo.jpg" alt="Claude Code on Android" width="200">
</p>

<p align="center">
  <strong>Run Claude Code natively on Android — no root, no emulator, no cloud VM.</strong>
</p>

<p align="center">
  <strong>Claude Code</strong> is Anthropic's AI coding assistant that runs in your terminal. It reads files, writes code, runs commands, and manages projects — all through conversation. This repo gets it running on an Android phone.
</p>

<p align="center">
  <img src="assets/screenshot-s26ultra.jpg" alt="Samsung Galaxy S26 Ultra running Claude Code" width="260">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/screenshot-pixel10pro.jpg" alt="Google Pixel 10 Pro running Claude Code" width="260">
</p>
<p align="center">
  <em>S26 Ultra (Android 16) · Pixel 10 Pro (Android 16) · <a href="assets/">more screenshots</a></em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Android-14%2B-brightgreen.svg" alt="Android 14+">
  <img src="https://img.shields.io/badge/Version-2.3.0-blue.svg" alt="Version 2.3.0">
  <img src="https://img.shields.io/badge/Last%20Verified-March%202026-lightgrey.svg" alt="Last Verified March 2026">
</p>

<p align="center">
  <a href="docs/install.md">Install Guide</a> · <a href="docs/troubleshooting.md">Troubleshooting</a> · <a href="docs/adb-wireless.md">ADB Wireless</a> · <a href="docs/constitution-template.md">CLAUDE.md Template</a> · <a href="docs/agents.md">Meet the Crew</a> · <a href="docs/story.md">Our Story</a>
</p>

---

## Security Warning

> **Read this before enabling wireless debugging.**
>
> ADB wireless debugging opens a network-accessible port on your device. Any device on the same WiFi network can attempt to pair. ADB requires a pairing code for every new connection, but the port is still exposed.
>
> **Best practice:** Enable wireless debugging only when you need it. Disable it when you're done. On public WiFi, it must be off. The connection from Termux is localhost-only (`127.0.0.1`), so the ADB server itself does not listen on external interfaces from the Termux side — but the Android wireless debugging daemon does.
>
> This is the same risk every Android developer accepts when using wireless debugging. It is documented here because many users of this guide may be encountering ADB for the first time. See [ADB-WIRELESS.md](docs/adb-wireless.md) for full security details.

---

## Prerequisites

You need **Termux** installed from **F-Droid** (not the Play Store — the Play Store version hasn't been updated since 2020 and will not work).

> **Architecture check first.** Open any terminal and run `uname -m`. You need `aarch64` (64-bit ARM). If you see `armv7l` or `armv8l`, your device runs a 32-bit OS and Claude Code cannot work — no workaround exists. Some budget phones (Galaxy A13, A02S, M13) ship 32-bit Android on 64-bit hardware. See [Troubleshooting](docs/troubleshooting.md#unsupported-architecture-armhf).

### Install Termux

1. Download F-Droid from [f-droid.org](https://f-droid.org/en/). F-Droid is an app store for open-source Android apps — it's where the maintained version of Termux lives.
2. Open the downloaded APK. Android will block it. Go to **Settings → allow "install unknown apps"** from your browser.
3. After installing F-Droid, go back to Settings and **disable "install unknown apps"** from your browser. Keep it enabled only for F-Droid (it needs it to install apps).
4. Open F-Droid, search for **Termux**, install it.
5. Android may warn "unsafe app — built for an older version." Tap **More details → Install anyway**. This is safe — Termux targets an older API level for broader compatibility.

### Install Required Packages

Once Termux is open:

```bash
pkg upgrade -y
pkg install proot-distro -y          # Required for Path B (recommended)
pkg install android-tools -y         # Required for ADB self-connect
```

If you plan to use Termux API features (battery status, TTS, camera, notifications, SMS, GPS):

```bash
pkg install termux-api -y
```

Then install the **Termux:API** companion app from F-Droid (search "Termux:API"). The `termux-api` package provides the commands; the companion app provides the Android permissions bridge.

> **Already have Termux from F-Droid with packages installed?** Skip to Quick Start.

---

## Quick Start

There are two ways to install Claude Code on Android. Both require a [Claude Pro or Max subscription](https://www.anthropic.com/pricing).

### Path B — Recommended (Full Linux Environment)

The cleanest setup. Installs Ubuntu inside Termux using proot-distro — think of it as a lightweight Linux environment running inside your phone's terminal. Claude Code runs in a standard Linux environment with no workarounds needed.

```bash
proot-distro install ubuntu
proot-distro login ubuntu
```

Inside Ubuntu:

```bash
apt update && apt upgrade -y
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
claude
```

Storage requirement: approximately 2 GB for the Ubuntu environment plus Claude Code.

> **Why `pkg upgrade` and `apt upgrade` first?** Without updated SSL libraries, the Claude Code installer returns 403. Both upgrades are required.

### Path A — Fully Viable with Node v25+

Faster setup (~2 min), less disk space, but requires workarounds that break on every Claude Code update.

```bash
pkg install nodejs git curl proot ripgrep -y
export TMPDIR=$PREFIX/tmp   # Critical: npm fails silently without this
npm install -g @anthropic-ai/claude-code
# Required: bare 'claude' will fail — always use this wrapper
proot -b $PREFIX/tmp:/tmp claude
```

Add this to `~/.bashrc` so it persists:

```bash
echo 'export TMPDIR=$PREFIX/tmp' >> ~/.bashrc
echo "alias claude-android='proot -b \$PREFIX/tmp:/tmp claude'" >> ~/.bashrc
source ~/.bashrc
```

> **Scripted install:** There's also a [one-command installer](install.sh) for Path A.

### Which Path Should I Use?

| | Path A (Native Termux) | Path B (Ubuntu in Termux) |
|---|---|---|
| Setup time | ~2 minutes | ~10-15 minutes |
| Disk usage | Minimal | ~2 GB |
| Install method | npm | Official Anthropic installer |
| Node.js required | Yes | No |
| /tmp workaround | Required every launch | Not needed |
| Ripgrep fix | Required, breaks on updates | Not needed |
| Ongoing maintenance | Re-fix after each update | Just update normally |
| Best for | Experienced users, light usage | Everyone else |

> **First timer?** Use Path B. Fewer things break.

### Your First Session

Once you've installed Claude Code and authenticated:

1. Create a project folder: `mkdir ~/myproject && cd ~/myproject`
2. Launch: `claude`
3. Try: "What files are in this directory?"
4. Type `/help` to see available commands
5. If you install the skills below, `/doctor` verifies your setup

---

## Why This Is Hard

Running Claude Code on Android means solving problems that don't exist on desktop.

### /tmp doesn't exist

Claude Code expects a writable `/tmp` for sockets and internal communication. Android doesn't provide one. Without it, Claude Code fails silently — no error message, no crash log, just nothing. Path A fixes this with `proot -b $PREFIX/tmp:/tmp`. Path B avoids it entirely because Ubuntu has native `/tmp`. There's also a `CLAUDE_CODE_TMPDIR` environment variable — set it to any writable folder in your shell profile and Claude Code will use that instead of `/tmp`.

### Node.js v24 may hang

Node.js v24 can hang on startup under native Termux on 64-bit ARM (aarch64) devices. This is specific to v24, not Termux generally. v25 resolves it. Upgrading to v25+ or using Path B (which uses the native binary installer instead of Node.js) avoids the issue. Inside proot-distro Ubuntu, Node v24+ works fine.

### Missing ripgrep binary

Claude Code bundles ripgrep for its search tools but ships no ARM64 Android build. Path A needs a symlink workaround (the `/fix-ripgrep` skill handles this). Path B doesn't need it — Ubuntu's ripgrep is available through the PATH.

### Platform detection mismatch

Inside proot-distro Ubuntu, Claude Code identifies itself as running on Linux. In native Termux, it identifies as running on Android. Many packages and tools behave differently depending on which platform they detect. Tool failures in native Termux sometimes resolve themselves inside the Ubuntu guest for this reason alone.

---


## MCP (Model Context Protocol)

Two of three MCP transport types work on Android:

- **Remote HTTP servers** (e.g., Cloudflare) -- connect over HTTPS, zero local install. Best option for mobile.
- **Local stdio servers** (e.g., `npx -y @modelcontextprotocol/server-memory`) -- spawns child processes via npx. Tested with Node.js v25.8.1.
- **OAuth-based MCP servers** -- expected to fail. Termux has no browser redirect mechanism (`xdg-open` does not exist). Use token-based auth instead.

To add a remote MCP server:
```
claude mcp add --transport http <name> <url>
```

To add a local stdio server:
```
claude mcp add <name> -- npx -y <package>
```

---

## ADB Wireless Self-Connect

By connecting your phone to itself over ADB wireless debugging, Claude Code gains access to system capabilities that Android normally blocks from Termux. No root required. No computer needed.

### What ADB Unlocks

| Capability | Without ADB | With ADB |
|------------|------------|----------|
| Screenshots | Blocked | `adb shell screencap` |
| System settings (brightness, DND) | Blocked | `adb shell settings get/put` |
| Calendar events | Blocked | `adb shell content query` |
| Installed apps list | Blocked | `adb shell pm list packages` |
| Touch and gesture injection | Blocked | `adb shell input tap/swipe/text` |
| Process inspection | Blocked | `adb shell ps -A` / `dumpsys` |
| Launch/stop apps | Partial | `adb shell am start/force-stop` |
| Device properties | Blocked | `adb shell getprop` |

These work alongside Termux API features (camera, TTS, clipboard, GPS, SMS, notifications, sensors, vibration) which don't need ADB at all.

### Quick Setup

```bash
# In Termux (not inside Ubuntu):
pkg install android-tools -y

# On your phone: Settings → Developer Options → Wireless Debugging → ON
# Tap "Pair device with pairing code" — note the IP:port and pairing code

adb pair 127.0.0.1:<pairing-port> <pairing-code>
adb connect 127.0.0.1:<connection-port>
adb devices   # Should show your device
```

ADB works from inside the Ubuntu guest too. Setup takes about 5 minutes. See **[ADB-WIRELESS.md](docs/adb-wireless.md)** for the complete guide, security details, and persistence notes.

> **Requires WiFi.** Android checks for a WiFi association (not internet access). ADB wireless disables automatically on mobile data.

---

## Alternative: Remote Control

If you have a desktop or laptop running Claude Code, [Remote Control](https://docs.anthropic.com/en/docs/claude-code/remote-control) lets you control it from your phone via QR code. No Termux needed.

**Use Remote Control** when you have a desktop nearby and want quick mobile access.
**Use this repo's approach** when you want Claude Code running locally on your phone with no desktop dependency.

---

## What's In This Repo

### Guides

| Document | What It Covers |
|----------|---------------|
| **[INSTALL.md](docs/install.md)** | Full step-by-step setup for both paths, verification, maintenance |
| **[TROUBLESHOOTING.md](docs/troubleshooting.md)** | 17+ common failures with symptoms, causes, and fixes |
| **[ADB-WIRELESS.md](docs/adb-wireless.md)** | ADB self-connect setup, security model, capability table |
| **[CONSTITUTION-TEMPLATE.md](docs/constitution-template.md)** | CLAUDE.md template with Android/Termux constraints baked in |
| **[SENSORS.md](docs/sensors.md)** | NDK sensor access from Termux -- 9 of 11 standard types confirmed working |
| **[SSRF-GUARD.md](docs/ssrf-guard.md)** | WebFetch safety hook blocking private/reserved IP ranges |
| **[AGENT-PERMISSIONS.md](docs/agent-permissions.md)** | Permission separation guide -- no agent gets both web and write access |

### Tools & Config

| Item | What It Does |
|------|-------------|
| **[install.sh](install.sh)** | One-command installer for Path A |
| **[.claude/skills/](.claude/skills/)** | 8 Claude Code skills — Android diagnostics and workflow tools |
| **[tests/](tests/)** | Verification suite — tests documentation claims against your device |

### Project

| Document | What It Covers |
|----------|---------------|
| **[CHANGELOG.md](CHANGELOG.md)** | Version history from 0.1.0 to 2.3.0 |
| **[CONTRIBUTING.md](.github/CONTRIBUTING.md)** | How to contribute, report bugs, submit device reports |
| **[AGENTS.md](docs/agents.md)** | The 6 AI agents that build and maintain this repo |
| **[STORY.md](docs/story.md)** | How this project came together |

---

## Device Compatibility

| Device | Android | Path A | Path B | ADB | Last Verified |
|--------|---------|--------|--------|-----|---------------|
| Samsung Galaxy S26 Ultra | 16 | Works | Works | Works | 2026-03-19 |
| Google Pixel 10 Pro | 16 | Works | Works | Untested | 2026-03-19 |
| Samsung Galaxy S23+ | 15 | Untested | Works | Untested | 2026-03-19 |
| Samsung Galaxy S24/S25 | 15-16 | Untested | Untested | Untested | — |
| Google Pixel 8/9 | 15-16 | Untested | Untested | Untested | — |
| OnePlus 12/13 | 14-15 | Untested | Untested | Untested | — |

**Verified** means install, authentication, and basic operations tested end-to-end on real hardware. Test results: [tests/results/](tests/results/)

**Tested on your device?** [Submit a device report](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) to help fill in the gaps.

---

## PDF Reading

### PDF reading requires `which` shim

Claude Code's PDF reader checks for `pdftoppm` using `which`, but Termux doesn't ship a `which` binary.

See [Troubleshooting: PDF reading](docs/troubleshooting.md#pdf-reading-fails-pdftoppm-is-not-installed) for the fix.

---

## Known Constraints

Running on a phone means real limits. Path B (Ubuntu) resolves some of them.

| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| No root | No `sudo`, no ports below 1024 | Use ports 1024+, skip anything needing root |
| No systemd | No system services in native Termux. Inside Ubuntu, `cron` and some daemons work. | Use `crond` or shell scripts for scheduling |
| ~512MB Node.js heap | Large datasets must stream | Process incrementally, don't buffer |
| File descriptor limits | Heavy I/O can hit limits on some devices | Limit concurrent processes. Check with `ulimit -n` |
| Phantom process killer | Android may kill excess background processes | Disable in Developer Options if available, or limit background processes |
| /tmp is volatile (Path A) | proot crash = mount gone | Path B avoids this. Don't store persistent state in /tmp |
| WiFi required for ADB | ADB wireless disables on mobile data | Re-connect when back on WiFi |

See [TROUBLESHOOTING.md](docs/troubleshooting.md) for detailed fixes.

---

## Skills

This repo includes [Claude Code skills](https://docs.anthropic.com/en/docs/claude-code/skills) for Android and general-purpose workflow.

### Android / Termux

| Skill | What It Does |
|-------|-------------|
| `/doctor` | Diagnose your full Termux + Claude Code setup in one pass |
| `/fix-ripgrep` | Fix broken search tools (missing ARM64 Android binary) |
| `termux-safe` | Auto-loaded rules preventing `sudo`, wrong paths, silent failures |

### Workflow (works anywhere)

| Skill | What It Does |
|-------|-------------|
| `/audience-first` | Define your audience before publishing |
| `/scope-framing` | Frame research before starting — what decision does this serve? |
| `/config-validator` | Audit `.claude/` directory for consistency |
| `/minimum-viable` | Justify tool choices — can a shell script do this? |
| `/search-optimized-writing` | Write docs that are findable — error messages, searchable headings |

### Installing Skills

Copy them to your home directory so they work in any project:

```bash
cd ~
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
mkdir -p ~/.claude/skills
cp -r claude-code-android/.claude/skills/* ~/.claude/skills/
ls ~/.claude/skills/
rm -rf claude-code-android   # Clean up — phone storage is finite
```

---

## The CLAUDE.md Template

Claude Code reads a CLAUDE.md file from your project root for persistent rules. The [template](docs/constitution-template.md) in this repo is designed for Android and Termux — it includes platform constraints, safety rules, and agent configuration for up to 6 concurrent agents.

---

## The Agents

This repo is built and maintained by 6 AI agents — Claude Code instances with defined roles, coordinated by a lead instance. They run up to 6 concurrently on a single phone.

| Agent | Role |
|-------|------|
| **Pilgrim** | Lead instance. Routes tasks, reviews work, enforces rules. |
| **Architect** | Planning and design. Read-only — proposes, never executes. |
| **Librarian** | External research and verification. Finds facts, challenges assumptions. |
| **Smith** | Code, testing, debugging. Builds it, then tries to break it. |
| **Chronicler** | Documentation. Turns decisions into readable records. |
| **Curator** | Repo hygiene. Config, links, file organization, missing standards. |
| **Herald** | Audience-facing content. Community posts, announcements, descriptions. |

See [AGENTS.md](docs/agents.md) for the full breakdown.

---

## Contributing

Found a bug? Got it working on a new device? Know a better workaround?

- **Bug reports:** [Open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=bug_report.md)
- **Device reports:** [Submit compatibility data](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md)
- **Improvements:** PRs welcome. See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

---

## About This Project

This repo is built and maintained using Claude Code running on the same Android device it documents — the tool documenting itself, on the platform it's documenting. The operator ([FerrumFluxFenice](https://github.com/FerrumFluxFenice)) guides the work, Claude Code builds it, and every claim is verified on real hardware.

Claude Code is made by [Anthropic](https://www.anthropic.com). Official repo: [anthropics/claude-code](https://github.com/anthropics/claude-code).

## License

MIT. See [LICENSE](LICENSE).

---

<p align="center">
  <em>Built on a phone, in Termux, on ARM64, on Android.</em><br>
  <em>By a human and an AI, working together.</em><br>
  <em>v2.3.0</em>
</p>
