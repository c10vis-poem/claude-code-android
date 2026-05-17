# Claude Code on Android

<p align="center">
  <img src="assets/logo.png" alt="Claude Code on Android" width="200">
</p>

<p align="center">
  <strong>Run Claude Code natively on Android. No root, no emulator, no cloud VM.</strong>
</p>

<p align="center">
  <strong>Claude Code</strong> is Anthropic's AI coding assistant that runs in your terminal. It reads files, writes code, runs commands, and manages projects, all through conversation. This repo gets it running on an Android phone.
</p>

<p align="center">
  <img src="assets/screenshot-s26ultra.jpg" alt="Samsung Galaxy S26 Ultra running Claude Code" width="280">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/screenshot-pixel10pro.png" alt="Google Pixel 10 Pro running Claude Code" width="280">
</p>
<p align="center">
  <em>S26 Ultra (Android 16) · Pixel 10 Pro (Android 17) · <a href="assets/">more screenshots</a></em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Android-8%2B-brightgreen.svg" alt="Android 8+">
  <img src="https://img.shields.io/badge/Version-2.8.0-blue.svg" alt="Version 2.8.0">
  <img src="https://img.shields.io/badge/Last%20Verified-2026--05--16-lightgrey.svg" alt="Last Verified 2026-05-16">
</p>

<p align="center">
  <a href="docs/install.md">Install Guide</a> · <a href="docs/faq.md">FAQ</a> · <a href="docs/troubleshooting.md">Troubleshooting</a> · <a href="docs/security-model.md">Security Model</a> · <a href="docs/adb-wireless.md">ADB Wireless</a> · <a href="docs/avf-guide.md">AVF (Path C)</a> · <a href="docs/constitution-template.md">CLAUDE.md Template</a>
</p>

> ⚠️ **Path A users:** Upstream `@anthropic-ai/claude-code` 2.1.113+ has no android-arm64 build. The Quick Install below pins Path A to 2.1.112 and locks it against the in-process auto-updater. Path B (proot-Ubuntu) is unaffected. [Recovery for a broken install →](docs/install.md#recovery-from-the-april-18-upstream-regression)

---

## Quick Install

Pick a path. Run the commands.

### Path B -- Recommended (proot-Ubuntu)

Latest Claude Code, no version pin, no workarounds.

```bash
pkg install proot-distro -y
proot-distro install ubuntu && proot-distro login ubuntu
# Prompt changes to root@localhost. Inside Ubuntu:
apt update && apt upgrade -y
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
claude
```

Full walkthrough: **[docs/install.md#path-b-proot-distro-ubuntu](docs/install.md#path-b-proot-distro-ubuntu)**.

### Path A -- Native Termux (pinned to 2.1.112)

Lightweight footprint. One-line installer handles the version pin and the `chmod` lock that defends it against the auto-updater.

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
bash install.sh
claude
```

[`install.sh`](install.sh) installs Node.js, installs `@anthropic-ai/claude-code@2.1.112`, and locks the install directory read-only so the in-process auto-updater cannot replace it with a 2.1.113+ build that has no android-arm64 binary. You then just run `claude`. Want to read it first? **[View install.sh on GitHub](install.sh)** before running.

Full walkthrough: **[docs/install.md](docs/install.md)**.

### Path C -- AVF Linux VM (Pixel 6+, experimental)

Real Linux kernel via Android Virtualization Framework. Enable in Developer Options → Linux development environment. Setup + ADB hardware bridge details: **[docs/avf-guide.md](docs/avf-guide.md)**.

### Not sure which path?

**[docs/install.md#choose-your-path](docs/install.md#choose-your-path)** has a side-by-side comparison. Default: Path B.

---

## Prerequisites

You need **Termux** from **F-Droid** (not Play Store; that version is from 2020 and will not work). Architecture must be aarch64 -- run `uname -m` to confirm. Full prerequisites including the Termux:API source-matching rule: **[docs/install.md#prerequisites](docs/install.md#prerequisites)**.

---

## Your First Session

After install + authentication:

1. Create a project folder: `mkdir ~/myproject && cd ~/myproject`
2. Launch: `claude`
3. Try: "What files are in this directory?"
4. Type `/help` to see available commands

Authentication may fail to open a browser on Android 8 (and possibly 9). Copy the URL from the terminal and open it manually. [FAQ entry](docs/faq.md#claude-prints-a-url-but-my-browser-doesnt-open).

---

## What's In This Repo

### Guides

| Document | Covers |
|----------|---------------|
| [docs/install.md](docs/install.md) | Full step-by-step setup for all three paths, verification, maintenance |
| [docs/faq.md](docs/faq.md) | Install gotchas, path-choice questions, Android-version-specific behavior |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Symptom-shaped entries: errors, hangs, failures with their fixes |
| [docs/skills.md](docs/skills.md) | Claude Code skills shipped in `.claude/skills/` and scripts under `scripts/` |
| [docs/adb-wireless.md](docs/adb-wireless.md) | ADB self-connect: setup, security model, capability table |
| [docs/security-model.md](docs/security-model.md) | Threat model: Termux:API permissions, ADB escalation, mitigations |
| [docs/agent-permissions.md](docs/agent-permissions.md) | No-agent-with-both-web-and-write permission matrix |
| [docs/ssrf-guard.md](docs/ssrf-guard.md) | WebFetch safety hook blocking private/reserved IPs |
| [docs/fingerprint-gate.md](docs/fingerprint-gate.md) | Biometric approval gate using `termux-fingerprint` |
| [docs/constitution-template.md](docs/constitution-template.md) | CLAUDE.md template with Android/Termux constraints baked in |
| [docs/avf-guide.md](docs/avf-guide.md) | AVF setup, VM configuration, ADB hardware bridge |
| [docs/sensors.md](docs/sensors.md) | NDK sensor access from Termux |

### Tools

| Item | Does |
|------|-------------|
| [install.sh](install.sh) | One-command Path A installer |
| [scripts/](scripts/) | `check-termux-env.sh`, `fix-ripgrep.sh`, `config-validator.sh` |
| [.claude/skills/](.claude/skills/) | `minimum-viable`, `scope-framing`, `termux-safe` |
| [tests/](tests/) | `verify-claims.sh` (13 PASS/FAIL/SKIP claims); `ssrf-guard-tests.sh` |

### Project

| | |
|----------|---------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history from 0.1.0 to 2.8.0 |
| [CONTRIBUTING.md](.github/CONTRIBUTING.md) | How to contribute, report bugs, submit device reports |

---

## Device Compatibility

Per-device last-verified dates below. Most recent verification cycle: 2026-05-16.

| Device | Android | Path A | Path B | Last Verified |
|--------|---------|--------|--------|---------------|
| Samsung Galaxy S26 Ultra | 16 | ✅ | ✅ | 2026-03-19 |
| Google Pixel 10 Pro | 17 Beta | ✅ | ✅ | 2026-05-16 |
| Google Pixel 6 | 13 | ✅ | ✅ | 2026-05-16 |
| Motorola Moto G7 Power | 10 | ✅ | ✅ | 2026-05-16 |
| Samsung Galaxy S7 (SM-G930P) | 8 | ✅ | ✅ (manual URL paste) | 2026-05-16 |
| Samsung Galaxy S23+ | 15 | n/a | ✅ | 2026-03-19 |

Full per-device test output: **[tests/results/](tests/results/)**. AVF tested on Pixel 10 Pro (Android 16) 2026-04-01; see [docs/avf-guide.md](docs/avf-guide.md). [Submit a device report](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) if you've tested on hardware not listed.

---

## Alternative: Remote Control

If you have a desktop or laptop running Claude Code, [Remote Control](https://code.claude.com/docs/en/remote-control) lets you control it from your phone via QR code. Use Remote Control when you have a desktop nearby; use this repo when you want Claude Code running locally on your phone.

---

## MCP, Voice, PDF, ADB

These features work on Android with specifics covered in their own docs.

- **MCP:** Remote HTTP and local stdio transports work on both Path A and Path B. OAuth-based servers depend on the Android browser being able to reach a localhost callback; reliability varies by path and device. See [troubleshooting](docs/troubleshooting.md).
- **Voice mode:** SoX → PulseAudio → backend chain works on most devices; some vendor builds break at the SLES backend. Mic input is in flight via [termux-packages#29319](https://github.com/termux/termux-packages/pull/29319).
- **PDF reading:** Requires a `which` shim; see [troubleshooting](docs/troubleshooting.md#pdf-reading-fails-pdftoppm-is-not-installed).
- **ADB wireless self-connect:** Pair the phone to itself for system-level capabilities (screen capture, input injection, content queries). Full guide: [docs/adb-wireless.md](docs/adb-wireless.md).

---

## Contributing

Found a bug? Got it working on a new device? Know a better workaround?

- **Bug reports:** [Open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=bug_report.md)
- **Device reports:** [Submit compatibility data](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md)
- **Improvements:** PRs welcome. See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

---

## From the Maintainer

Erin here. I have seen a noticeable uptick in traffic lately. While this update did not ADD much I did make significant changes. My goal is a repository that will help those who want to run Claude Code on their Android device. The same way they could on their PC. That is what I wanted when I did it. I know their are other information sources out there and I say never treat anything as canonical. Verify everything.

If you find something that doesn't work for you, is factually incorrect, or anything other of note. Open an issue, tell me in some way. My goal is to help, learn, and grow. My presence is only for positive. I am not a lot of things. I do not have a fancy piece of paper, CompTIA certifications, or 5+ years ML experience. I am a truly curious, excited, and tech-forward guy who loves the grunt work and what AI can do, computing and how its done in general, networking and the security behind it and more.

If you are reading this and enjoy the repo I thank you for your time. I don't know exactly what 55 stars means or the 10 forks as of the time I am writing this but I do know one thing. My GitHub profile isn't going silent anytime soon. I am going to keep maintaining this and working on other projects along the way to grow myself into the best I can be.

[@ferrumclaudepilgrim](https://github.com/ferrumclaudepilgrim)  ·  Ferrum_Flux_Fenice  ·  Erin

---

## License

MIT. See [LICENSE](LICENSE).

## Built on and assisted by:

- **Claude Code** by [Anthropic](https://www.anthropic.com) -- official repo: [anthropics/claude-code](https://github.com/anthropics/claude-code)
- **Termux** -- the Android terminal that makes all of this possible: [termux/termux-app](https://github.com/termux)

Maintained by [@ferrumclaudepilgrim](https://github.com/ferrumclaudepilgrim). Issues and pull requests welcome.
