# Claude Code on Android

<p align="center">
  <img src="assets/logo.png" alt="Claude Code on Android" width="200">
</p>

<p align="center">
  <strong>Run Claude Code on your Android phone. No root, no emulator, no cloud VM.</strong>
</p>

<p align="center">
  <strong>Claude Code</strong> is Anthropic's AI coding assistant that runs in your terminal (a text-command app, in this case the Termux app on Android). It reads files, writes code, runs commands, and manages projects, all through conversation. This repo gets it running on an Android phone.
</p>

<p align="center">
  <img src="assets/screenshot-pixel10pro.png" alt="Google Pixel 10 Pro running Claude Code" width="280">
  <br>
  <img src="assets/screenshot-s26ultra.jpg" alt="Samsung Galaxy S26 Ultra running Claude Code" width="280">
</p>
<p align="center">
  <em>Pixel 10 Pro (Android 17) and S26 Ultra (Android 16), both running in Termux · <a href="assets/">more screenshots</a><br>(The S26 Ultra runs fine in Termux; the "not supported" note further down is only about Path C, the built-in virtual machine.)</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Android-8%2B-brightgreen.svg" alt="Android 8+">
  <img src="https://img.shields.io/badge/Version-2.9.3-blue.svg" alt="Version 2.9.3">
  <img src="https://img.shields.io/badge/Last%20Verified-2026--07--27-lightgrey.svg" alt="Last Verified 2026-07-27">
</p>

<p align="center">
  <a href="docs/install.md">Install Guide</a> · <a href="docs/faq.md">FAQ</a> · <a href="docs/troubleshooting.md">Troubleshooting</a> · <a href="docs/security-model.md">Security Model</a> · <a href="docs/adb-wireless.md">ADB Wireless</a> · <a href="docs/avf-guide.md">Android Virtualization Framework (Path C)</a> · <a href="docs/constitution-template.md">CLAUDE.md Template</a>
</p>

<p align="center">
  <a href="#before-you-start">Before You Start</a> · <a href="#quick-install">Quick Install</a> · <a href="#device-compatibility">Device Compatibility</a> · <a href="#other-projects-other-ways-in">Other Projects</a>
</p>

> [!TIP]
> **Upgrading, or hitting a launch error or a "Checking connectivity" hang?** See [Troubleshooting](docs/troubleshooting.md) for the recovery steps. Your login and settings are kept.

---

## Before You Start

What you need in place before any command in this guide can succeed:

These three prerequisites are for **Path A** and **Path B**, which both run in Termux. **Path C**, which runs on the Android Virtualization Framework (AVF, Android's built-in support for running a real Linux virtual machine), does not use Termux at all: it needs a Pixel 6 or later on Android 16 or later with Developer options turned on. If that is your setup, skip ahead to [Path C: AVF Linux VM](#path-c-avf-linux-vm-pixel-6-with-android-16-experimental).

1. **An aarch64 (64-bit ARM) Android phone, Android 8 or later.** Most Android phones from 2018 onward qualify. A few budget Samsung A-series models ship a 32-bit OS on 64-bit hardware and will not work; see the [Troubleshooting entry on `armv7l` / `armv8l`](docs/troubleshooting.md#unsupported-architecture-armhf) if `uname -m` (a command that prints your device's CPU architecture) returns those once you have a terminal open.
2. **A Claude account** (Pro, Max, Team, Enterprise, or a Console / API account, meaning a pay-as-you-go developer account at console.anthropic.com). Claude Code uses your existing Anthropic login.
3. **Termux installed from F-Droid or GitHub.** Termux is the terminal-emulator app the install commands below run in. The upstream Termux maintainers recommend F-Droid or their GitHub releases for most users. There is a Google Play build but as of the upstream README it is an experimental branch with missing functionality and bugs, and the upstream project recommends against it for most users. See [github.com/termux/termux-app](https://github.com/termux/termux-app) for the full install source breakdown and current caveats from the Termux maintainers themselves.

**If you have never used F-Droid or Termux before**, the upstream maintainers already cover the install steps better than this repo can:

- F-Droid (the open-source Android app store you install as an APK): [f-droid.org](https://f-droid.org/). The front page has the install instructions and the Play Protect prompt you may see on first launch.
- Termux on F-Droid: [f-droid.org/en/packages/com.termux/](https://f-droid.org/en/packages/com.termux/). You can install F-Droid first and then install Termux from inside it, or download the Termux APK directly from that page.
- Termux project (background, FAQ, troubleshooting): [github.com/termux/termux-app](https://github.com/termux/termux-app), [wiki.termux.com](https://wiki.termux.com/).

Once Termux is open you will see a prompt that looks like `~ $`. That is where the commands in Quick Install go. (Long-press to paste, or tap the on-screen Ctrl key then press V.)

Full prerequisites including the Termux:API source-matching rule: **[docs/install.md#prerequisites](docs/install.md#prerequisites)**.

---

## Quick Install

The repo documents three install paths. Pick one before pasting commands:

- **Path A (native Termux).** The official linux-arm64 claude binary, patched to run on Android, with a wrapper that checks once a day for a new version and updates transparently. About 5 to 10 minutes to install, a few hundred megabytes on disk, and about 200 MB more if you accept the recommended packages. One thing to know up front: on launch it points Claude Code's own DNS lookups at Google's public resolvers (`8.8.8.8` / `8.8.4.4`) to sidestep a connectivity hang, which overrides a VPN, split-tunnel, or Pi-hole resolver for those queries (see [Security Model](docs/security-model.md#path-a-forces-google-dns-for-claude-codes-own-lookups)).
- **Path B (proot-distro Ubuntu).** Latest Claude Code installed via Anthropic's official installer inside a full Ubuntu environment. Heavier at ~2 GB on disk, but `process.platform` reports `linux` and standard Linux conventions all apply. (`process.platform` is the runtime identifier of the host operating system, which some tools branch on.)
- **Path C (AVF Linux VM, experimental).** Real Linux kernel via Android's built-in virtual machine support (the hypervisor). Doesn't use Termux at all. Needs a Pixel 6 or later on Android 16 or later. The Exynos Galaxy S26 / S26+ are reported to work but I have not lab-verified them; Snapdragon devices, including the S26 Ultra, are not supported.

Which should you pick? Path A is the default: it is what `install.sh` sets up, and it keeps itself current, so if you are not sure, start there. My own take on the tradeoffs is in the note below. Side-by-side comparison: [docs/install.md#choose-your-path](docs/install.md#choose-your-path).

> [!NOTE]
> **Which path I run, and why:** I run Path A (native Termux) myself. It is what `install.sh` sets up, it keeps itself current, and it is what I migrated my own daily driver to. If you would rather keep a patched-binary wrapper out of the loop, Path B (proot-distro Ubuntu) is the simplest way to keep Claude Code self-updating through Anthropic's official installer, the same as on a PC. Path C (AVF) is arguably the most genuinely native option, though its coverage is still narrow. Pick the one that fits your device; I am just sharing what I run.

If you are coming up from an older pinned `2.1.112` install, follow [Upgrading from a pinned install](docs/install.md#upgrading-from-a-pinned-v2x-install). Not sure which install you have? `claude --version` reports Claude Code's own version (the 2.1.x number), not this repo's, so it will not tell you; see [Which setup am I on?](docs/troubleshooting.md#which-setup-am-i-on) for a one-command check.

### Path A: Native Termux

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
bash install.sh
```

The installer asks two yes/no questions, then runs unattended. When it finishes, type:

```bash
claude
```

Here is what [`install.sh`](install.sh) does, start to finish:

- Installs Termux's `glibc-runner` and `patchelf-glibc`.
- Downloads the official linux-arm64 claude binary from Anthropic's CDN (the content-delivery servers the file is hosted on) and verifies the checksum (a fingerprint that confirms the download arrived intact from Anthropic) against Anthropic's published list. The binary and its checksum come from the same Anthropic host, so this catches a corrupted or truncated download; it is not upstream code signing and does not by itself prove the source was not compromised.
- Patches the binary's ELF interpreter so Android can run it. ELF (Executable and Linkable Format) is the standard format for Linux programs, and the "interpreter" is the loader it asks for at startup; this step points the binary at the Termux-provided one.
- Drops a wrapper at `$PREFIX/bin/claude` (`$PREFIX` is Termux's own install folder) that auto-checks for new claude releases once a day on launch.

The wrapper accepts a `--update-now` flag to force an immediate check; this is a Path A wrapper feature, not a built-in Claude Code flag. Want to read it first? **[View install.sh on GitHub](install.sh)** before running.

Full walkthrough: **[docs/install.md](docs/install.md)**.

Prefer the smallest, simplest install and do not need current claude? [`install-pinned.sh`](install-pinned.sh) pins Claude Code `2.1.112` (the last version with a JS entry point) with no binary patching and no auto-updating wrapper. It stays at that version; `install.sh` above is the default for current claude.

> [!IMPORTANT]
> **Path A runs on a compatibility workaround.** Anthropic ships Claude Code as a glibc-linked Linux binary, with no Android build. Termux runs on Android's Bionic C library, so any version past the old pinned `2.1.112` runs here only because `install.sh` patches the official linux-arm64 binary to load through Termux's glibc-runner. It works and stays current, but it is a shim, not native support.
>
> The real fix is upstream. There is no official Android build today; adding one would need either a `bun` `android-arm64` target or a static musl build. (`bun` is the JavaScript runtime Claude Code is bundled with; a static musl build would be a fully self-contained binary that does not rely on the host system's C library.) Until that ships, Path A depends on this patching step. Tracked at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270).

### Path B: proot-distro Ubuntu

Latest Claude Code inside a full Ubuntu environment.

```bash
pkg install proot-distro -y
proot-distro install ubuntu && proot-distro login ubuntu
```

This may take a few minutes depending on connection speed.

Upon completion the prompt changes to something like:
```
root@localhost:~#
```
That means you are now inside Ubuntu rather than Termux. Inside Ubuntu:
```
apt update && apt upgrade -y
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
claude
```

Full walkthrough: **[docs/install.md#path-b-proot-distro-ubuntu](docs/install.md#path-b-proot-distro-ubuntu)**.

### Path C: AVF Linux VM (Pixel 6+ with Android 16+, experimental)

Real Linux kernel via the Android Virtualization Framework. No Termux involved. Supported on Pixel 6 and later. The Exynos Galaxy S26 / S26+ are reported to work but I have not lab-verified them; Snapdragon devices, including the S26 Ultra, are not supported.

On the phone, open Settings > System > Developer options and toggle **Linux development environment** on. If Developer options is not visible, enable it first: Settings > About phone > tap **Build number** 7 times. (You only have to do this once per phone.) If the Linux development environment toggle still does not appear after enabling Developer options, your device does not support this path.

Open the Terminal app that appears on the home screen. Accept the prompt to download the Debian image. When the prompt shows `droid@debian:~$`, install Claude Code inside the VM:

```bash
curl -fsSL https://claude.ai/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
claude
```

The Terminal app's gear icon opens Settings, with Memory size, Display resolution, and Keep awake controls under **Advanced**. Full walkthrough including ADB hardware bridge, recovery, and known issues: **[docs/avf-guide.md](docs/avf-guide.md)**.

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
| [docs/security-model.md](docs/security-model.md) | What Claude Code can and cannot reach on your phone: Termux:API permissions, ADB access, and the limits on each |
| [docs/agent-permissions.md](docs/agent-permissions.md) | A rule set so no single automated helper can both read the web and write files (limits what a bad instruction could do) |
| [docs/ssrf-guard.md](docs/ssrf-guard.md) | An optional safety check that stops the web-fetch tool from reaching private or internal network addresses |
| [docs/fingerprint-gate.md](docs/fingerprint-gate.md) | An optional fingerprint prompt before risky actions, using Termux's `termux-fingerprint` |
| [docs/constitution-template.md](docs/constitution-template.md) | CLAUDE.md template with Android/Termux constraints baked in |
| [docs/avf-guide.md](docs/avf-guide.md) | Path C (virtual machine) setup, configuration, and hardware bridge |
| [docs/sensors.md](docs/sensors.md) | Reading device sensors from Termux using Android's native development kit (NDK) |

### Tools

| Item | Does |
|------|-------------|
| [install.sh](install.sh) | Path A installer (patched linux-arm64 binary + auto-updating wrapper) |
| [install-pinned.sh](install-pinned.sh) | Opt-in pinned installer (Claude Code 2.1.112, no patched binary, no auto-update); stays pinned |
| [migrate.sh](migrate.sh) | Upgrade a pinned v2.x install to the current auto-updating architecture, preserving sessions, login, and settings |
| [scripts/](scripts/) | `check-termux-env.sh`, `config-validator.sh`, and recovery helpers |
| [.claude/skills/](.claude/skills/) | `minimum-viable`, `scope-framing`, `termux-safe` |
| [tests/](tests/) | `verify-claims.sh` (per-claim PASS/FAIL/SKIP harness); `ssrf-guard-tests.sh` |

### Project

| | |
|----------|---------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history from 0.1.0 forward |
| [CONTRIBUTING.md](.github/CONTRIBUTING.md) | How to contribute, report bugs, submit device reports |

---

## Device Compatibility

Per-device verification dates. Android 10 and 8 cannot run the native binary: it trips Android's seccomp filter (the kernel feature that blocks certain low-level system calls) and crashes on launch, so those devices stay on the pinned `2.1.112` install (`install-pinned.sh`). Rows link a saved `verify-claims.sh` transcript where one exists; rows marked [^selfreport] were confirmed by hand on the date shown. This repo's version and Claude Code's own version are different numbers: see [Which setup am I on?](docs/troubleshooting.md#which-setup-am-i-on).

| Device | Android | Path A | Path B | Test artifact |
|--------|---------|--------|--------|---------------|
| Google Pixel 10 Pro [^pathc] | 17 | ✅ (2026-07-26) [^native][^selfreport] | ✅ | [pixel-10-pro-android17.txt](tests/results/pixel-10-pro-android17.txt) (v2.x) |
| Google Pixel 6 [^pathc] | 17 | ✅ (2026-07-27) [^native][^selfreport] | ✅ [^selfreport] | doc-only |
| Motorola Moto G7 Power | 10 | pinned only (2026-07-27) [^capA10] | ✅ | [moto-g(7)-power-android10.txt](tests/results/moto-g(7)-power-android10.txt) (v2.x) |
| Samsung Galaxy S7 (SM-G930P) | 8 | pinned only (2026-07-26) [^capA8] | ✅ (manual URL paste) | [sm-g930p-android8.0.0.txt](tests/results/sm-g930p-android8.0.0.txt) (v2.x) |
| Samsung Galaxy S26 Ultra | 16 | ✅ (2026-05-29) [^migrate][^selfreport] | ✅ [^selfreport] | doc-only |
| Samsung Galaxy S23+ | 15 | n/a | ✅ (2026-03-19) [^selfreport] | doc-only |

[^native]: Path A here runs the native binary through the auto-updating wrapper, which tracks the latest claude release rather than pinning a version.
[^capA10]: Path A here stays on pinned 2.1.112; the native binary is capped on Android 10.
[^capA8]: Path A here stays on pinned 2.1.112; the native binary is capped on Android 8.
[^migrate]: Verified on v2.9.0, installed via migrate.sh.
[^pathc]: Path C (AVF) was also verified on this device on 2026-05-26; see the note below the table and [docs/avf-guide.md](docs/avf-guide.md).
[^selfreport]: Verified by hand on the date shown. Any file linked in the last column is a transcript from an earlier run (its version is noted beside it); the date in this column was confirmed without a new captured transcript.

Path C (AVF) re-verified on Pixel 6 and Pixel 10 Pro running Android 17 on 2026-05-26; see [docs/avf-guide.md](docs/avf-guide.md). [Submit a device report](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.yml) if you've tested on hardware not listed.

---

## Alternative: Remote Control

If you have a desktop or laptop running Claude Code, [Remote Control](https://code.claude.com/docs/en/remote-control) lets you control it from your phone via QR code. Use Remote Control when you have a desktop nearby; use this repo when you want Claude Code running locally on your phone.

---

## Other Projects, Other Ways In

I am not the only one solving this. Depending on what you want, one of these may fit you better than my scripts do:

- **[gtbuchanan/claude-code-termux](https://github.com/gtbuchanan/claude-code-termux)** is where the patched-binary approach started (also credited below). It wraps the same download-and-ELF-patch idea in a cleaner apt `.deb` package, so if you would rather install from a package than run a shell script, look here first.
- **[Ishabdullah/claude-code-termux](https://github.com/Ishabdullah/claude-code-termux)** is a short guide rather than a script: install the `@anthropic-ai/claude-code` npm package (npm is Node's package manager) and run `claude` through a shell alias. That is the same territory as my `install-pinned.sh`. Worth knowing it covers the versions that still ship a JavaScript entry point, not the current native binary.

One to steer around: **techjarves/open-claude-code-termux** is not this repo and not the same thing. Despite the name, it runs a leaked build against third-party OpenRouter models, not real Claude Code with your Anthropic login. If you want the actual product, that is not where to get it.

---

## MCP, Voice, PDF, ADB

These features work on Android with specifics covered in their own docs.

- **MCP (Model Context Protocol, the standard Claude Code uses to connect to external tools and data sources):** Remote HTTP and local stdio transports work on both Path A and Path B. OAuth-based servers (servers that use the OAuth 2.0 authorization flow, which redirects through a browser to grant access tokens) depend on the Android browser being able to reach a localhost callback; reliability varies by path and device. See [troubleshooting](docs/troubleshooting.md).
- **Voice mode:** The SoX → PulseAudio → backend chain has worked on the devices I have tried, though some vendor builds break at the OpenSL ES backend on older Android versions. Test before relying on it. Mic input is in flight via [termux-packages#29074](https://github.com/termux/termux-packages/pull/29074). (SoX is a command-line audio toolkit; PulseAudio is the Linux sound server; OpenSL ES is the Android audio API PulseAudio uses to reach the device speaker.)
- **PDF reading:** Requires a `which` shim; see [troubleshooting](docs/troubleshooting.md#pdf-reading-fails-pdftoppm-is-not-installed).
- **ADB wireless self-connect:** Pair the phone to itself for system-level capabilities (screen capture, input injection, content queries). Full guide: [docs/adb-wireless.md](docs/adb-wireless.md).

---

## Contributing

Found a bug? Got it working on a new device? Know a better workaround?

- **Bug reports:** [Open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=bug_report.yml)
- **Device reports:** [Submit compatibility data](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.yml)
- **Improvements:** PRs welcome. See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

---

## From the Maintainer

Ferrum_Flux_Fenice here, aka Erin. If you haven't noticed, the pushes have slowed over the last few months. Most of that is stability. Even with the regression that pinned older devices to 2.1.112, the community on the issue thread and having this amazing tool inside Termux, on the device, have helped tremendously. Over time I have been trying to build this into a lasting repo that helps as many people as it can. I have a few more things I am working on, for the repo and in general.

If you want to be a part of it, or you find something to contribute or something broken, open an issue or a pull request. I enjoy being able to put some time forward, learn, and help others.

I maintain this alone and I am not a security professional, so treat nothing here as canonical: verify everything before you rely on it.

[@ferrumclaudepilgrim](https://github.com/ferrumclaudepilgrim)  ·  Ferrum_Flux_Fenice (my project alias)  ·  Erin

---

## License

MIT. See [LICENSE](LICENSE).

## Built on and assisted by:

- **Claude Code** by [Anthropic](https://www.anthropic.com): [anthropics/claude-code](https://github.com/anthropics/claude-code)
- **glibc-runner / patchelf-glibc:** Termux's glibc-packages project that makes running linux-arm64 binaries on Android possible: [termux/glibc-packages](https://github.com/termux/glibc-packages)
- **The patched-binary approach** was originally described by [gtbuchanan](https://github.com/gtbuchanan) in a comment on [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270). This repo's `install.sh` is built on top of that work with empirical verification, the auto-updating wrapper, and the interactive prompts added.
- **Termux:** the Android terminal that makes all of this possible: [termux/termux-app](https://github.com/termux)

Maintained by [@ferrumclaudepilgrim](https://github.com/ferrumclaudepilgrim). Issues and pull requests welcome.
</content>
