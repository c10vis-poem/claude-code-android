# Installing Claude Code on Android

A complete, reproducible guide to installing Claude Code (Anthropic's AI coding assistant) on Android. Three install paths: pick one. Path A is the smallest install and auto-updates on launch. Path B gives you a full Ubuntu environment. Path C runs a real Linux kernel via AVF (Android Virtualization Framework, the built-in hypervisor that ships with Android 16 on supported devices) and requires Pixel 6+ on Android 16+.

---

## Prerequisites

Before you begin, confirm you have the following:

| Component | Requirement |
|-----------|-------------|
| **Architecture** | aarch64 (64-bit ARM); once you have installed the terminal (see the Terminal row below), run `uname -m` in it to verify. If it returns `armv7l` or `armv8l`, Claude Code will not work on your device |
| **Device** | aarch64 Android device (ARM64) |
| **OS** | Android 8+ (Android 8 / 9 have OAuth caveats; OAuth is the browser-based login flow Claude Code uses to authenticate with Anthropic; see FAQ) |
| **Kernel** | Varies by Android version and OEM; use `uname -r` to check. Kernel versions observed on the test devices in this repo: Galaxy S7 / Android 8: 3.18.x, Moto G7 Power / Android 10: 4.9.x, Pixel 6: 5.10.x (measured when that device was on Android 13), Pixel 10 Pro / Android 17: 6.6.x. Your device may differ. |
| **Terminal** | [Termux from F-Droid](https://f-droid.org/en/packages/com.termux/) or the [GitHub releases](https://github.com/termux/termux-app/releases). F-Droid is an open-source Android app store you install as an APK. The Google Play build is an experimental branch; as of the upstream Termux README it has missing functionality and bugs, and the upstream project recommends against it for most users. |
| **Subscription** | Claude Pro, Max, Team, Enterprise, or Console account (provides the API access Claude Code requires) |
| **Network** | Active internet connection (Claude Code streams from Anthropic's API) |
| **Termux:API** | Optional. Both the `termux-api` package (`pkg install termux-api`) and the [Termux:API companion app from F-Droid](https://f-droid.org/en/packages/com.termux.api/) are needed for device features (battery, camera, TTS, SMS, GPS, sensors). Claude Code itself does not require them. |

> **Permission tip:** Only grant the Termux:API permissions your workflow requires. You can deny SMS, Contacts, Call Log, Camera, Microphone, and Location and still use Claude Code normally. See the [Security Model](security-model.md) for what each permission exposes.

> **Termux:API source-matching:** The `termux-api` package (installed via `pkg install termux-api`) and the Termux:API companion app **must come from the same source** (both F-Droid or both GitHub releases). Mixing sources causes silent permission failures that are difficult to diagnose. Without both the package and the app, Termux:API calls fail silently.

> **Warning:** As of the upstream Termux project README, the Google Play build is an experimental branch with missing functionality and known bugs; the upstream project recommends against it for most users. Use F-Droid or install the `.apk` directly from the [Termux GitHub releases](https://github.com/termux/termux-app/releases).

> **Path C (AVF) note:** The prerequisites above (Termux, Android 8+) are for Path A and Path B, which both run in Termux. Path C (AVF) does not use Termux. It needs a Pixel 6 or later on Android 16 or later with Developer options on. See [Choose Your Path](#choose-your-path) and [Path C](#path-c-avf-linux-vm-experimental).

---

## Choose Your Path

This guide covers three installation paths. Pick one before you start.

| | Path A: Native Termux | Path B: proot-distro Ubuntu | Path C: AVF Linux VM |
|---|---|---|---|
| **Best for** | Smallest install, latest claude, auto-updates | Full Ubuntu environment alongside Claude Code | Pixel 6+ on Android 16+, real Linux kernel via hypervisor |
| **Setup time** | 5-10 min | ~10-15 min | ~20 min |
| **Disk usage** | ~280 MB base install; about 200 MB more if you accept recommended packages | ~2 GB | ~2 GB |
| **Ongoing maintenance** | None (wrapper auto-updates) | Just update normally | Just update normally |
| **Install method** | Patched linux-arm64 binary via glibc-runner | Anthropic installer inside Ubuntu | Anthropic installer inside the VM |
| **Node.js required** | No | No | No |
| **Device support** | Any aarch64 Android 8+ (Android 8 / 9 have OAuth caveats; see FAQ) | Any aarch64 Android 8+ (Android 8 / 9 have OAuth caveats; see FAQ) | Pixel 6+ Android 16+ |
| **Stability** | Stable | Stable | Experimental |

**glibc-runner** is a Termux package that provides a glibc-compatible dynamic linker so glibc binaries run in Termux's Bionic-based environment (Bionic is Android's C library, the counterpart to glibc on desktop Linux). Path A uses it to run the linux-arm64 claude binary.

**Tradeoffs:** Path A has the smallest footprint (~280 MB base, or ~480 MB with recommended packages) and auto-updates on launch. Path B gives you a full Ubuntu environment with apt, standard `/tmp`, `/etc`, and glibc natively in place, at ~2 GB on disk. Path C runs a real Linux kernel via Android's hypervisor but requires Pixel 6+ on Android 16+ and is experimental.

[Jump to Path A](#path-a-native-termux) · [Jump to Path B](#path-b-proot-distro-ubuntu) · [Jump to Path C](#path-c-avf-linux-vm-experimental)

---

## Environment Reference

Key paths and versions for a Path A working installation:

- **Architecture:** aarch64 (ARM64)
- **Kernel:** Varies by Android version and OEM; verify with `uname -r`. See the Prerequisites table above for kernel versions observed on the test devices in this repo.
- **Shell:** Termux
- **Home (`$HOME`):** `/data/data/com.termux/files/home`
- **Prefix (`$PREFIX`):** `/data/data/com.termux/files/usr` (Termux's root directory for installed packages and binaries; analogous to `/usr` on a standard Linux system)
- **Patched binary:** `~/.local/share/claude/versions/<version>`
- **Wrapper:** `$PREFIX/bin/claude`
- **Settings:** `~/.claude/settings.json`

There is no root access. There is no systemd. The filesystem paths are deeply nested inside Android's app sandbox.

---

## Path A: Native Termux

The Path A install runs Anthropic's official linux-arm64 claude binary on Android by patching the binary's ELF interpreter (ELF, Executable and Linkable Format, is the binary format Linux programs use; the interpreter is the field in that binary that names the dynamic linker to use) to point at Termux's glibc-runner. A wrapper at `$PREFIX/bin/claude` checks once per day on launch for a newer version and updates without requiring any action from you.

### Step 1: Run install.sh

> **Older devices, read first:** If your device runs Android 8, 9, or 10, the native binary may not launch, because it can trip Android's seccomp system-call filter (this repo has seen it fail on the Android 8 and Android 10 test devices). On those devices, run [`install-pinned.sh`](../install-pinned.sh) instead of `install.sh`; it installs the pinned `2.1.112` release, which does run there. See [Tested On](#tested-on) below.

Open Termux and run:

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
bash install.sh
```

The installer asks two yes/no questions, then runs unattended:

- **Q1: Is this a fresh Termux install?** If yes, `pkg upgrade` (`pkg` is Termux's package manager, a wrapper around apt with mirror selection) takes the new defaults for any system config files. If no, your existing config files are preserved.
- **Q2: Install recommended packages?** If yes, installs git, gh, wget, jq, python, openssh, tree, proot, termux-api, proot-distro, make, clang, file, xxd, htop, bat, fzf. Roughly 200 MB of additional disk. Skip this if you prefer to install packages manually as needed.

You do not need to read the following to use Claude Code; skip to Step 2 to launch. For the curious, after the questions the installer:

1. Brings Termux base packages up to date
2. Installs `curl`, `jq`
3. Enables Termux's glibc-packages repo
4. Installs `glibc-runner` and `patchelf-glibc` (~50 MB). `patchelf-glibc` is a Termux-packaged version of the patchelf utility that can modify ELF binary metadata, used here to rewrite the binary's interpreter field.
5. Queries `https://registry.npmjs.org/@anthropic-ai/claude-code/latest` for the current version
6. Downloads the linux-arm64 claude binary from `https://downloads.claude.ai/claude-code-releases/<version>/linux-arm64/claude` (~233 MB)
7. Verifies the binary's sha256 checksum (sha256 is a cryptographic hash function; comparing the hash of the downloaded file against the published value confirms the file arrived intact and unmodified) against the published manifest (a `manifest.json` Anthropic publishes alongside each release, containing per-platform checksums)
8. Patches the binary's ELF interpreter to point at glibc-runner's `ld.so`
9. Writes a small DNS resolver preload at `~/.local/share/claude/setdns.js` (it points Node's resolver at `8.8.8.8` / `8.8.4.4`). The wrapper preloads it via `BUN_OPTIONS --preload` on every launch, which works around a connectivity hang some devices hit where a message stalls on "Checking connectivity" and fails with ETIMEOUT.
10. Writes `~/.claude/settings.json` with `"autoUpdates": false` so claude's in-process updater stays off (the wrapper handles updates). It does not set `env.LD_PRELOAD`, and removes any stale one a prior install left, because that preload leaked into claude's subprocesses and broke its bundled grep, rg, and ugrep. If a `settings.json` already exists, it is merged in place, keeping your other keys.
11. Drops the auto-updating wrapper at `$PREFIX/bin/claude`
12. If you answered yes to Q2, installs the recommended packages

Total install time: 5-10 minutes depending on connection speed.

### Step 2: Launch claude

The wrapper lands at `$PREFIX/bin/claude`, which is already on your PATH, so you can start right away:

```bash
claude
```

On first launch, claude opens its welcome wizard (theme selection, project trust prompt), then walks you through OAuth. Authentication may fail to open a browser on Android 8 / 9; if so, copy the URL from the terminal and open it manually. [FAQ entry](faq.md#claude-prints-a-url-but-my-browser-doesnt-open).

### What the wrapper does on every launch (optional reading)

The short version: each launch makes sure the installed version actually runs on your phone, checks for an update at most once a day, and on its own falls back to the last working version if an update turns out to be broken. The first time it runs a new version it may pause a few seconds to test it; that is normal, not a freeze. Step by step:

On each `claude` invocation, the wrapper:

1. Checks for updates, at most once every 24 hours (using a stamp file at `~/.local/share/claude/versions/.last-update-check`). If due, it queries the npm registry for the latest version. If a newer version is published, it downloads the binary, verifies the checksum, patches the ELF interpreter, and launch-tests it (item 2) before adopting it. A version that passes is moved into `~/.local/share/claude/versions/`; one that crashes on this device is discarded and recorded so it is not downloaded again. The previous working version is kept for rollback; older ones are removed.
2. Launch-tests the version it is about to run. Some upstream releases pass `--version` but crash on full launch, and there are two separate causes. On older Android, the seccomp filter blocks a low-level system call the binary issues (an Android 10 build has died on `statx`, a newer native build on `pidfd_open`). On newer phones the crash is a null pointer inside Termux's `glibc-runner` shim for `epoll_pwait2`, which the Bun runtime claude is built on calls at startup; that one is not a blocked system call. The wrapper boots the binary once with `--init-only` in a throwaway, isolated HOME, so your real `~/.claude`, login, and hooks are never touched. A version that crashes is added to a blocklist and skipped, and the wrapper falls back to the highest version that still works, so a bad auto-update rolls back on its own with no action from you. The version confirmed good is cached so the next launch skips the test.
3. Self-heals the ELF interpreter: if the binary's interpreter is wrong (because something replaced the binary outside the wrapper's knowledge), re-patches it before launch.
4. Preloads the DNS resolver fix. It makes sure `~/.local/share/claude/setdns.js` exists and exports `BUN_OPTIONS --preload` so the binary starts with it, which keeps the "Checking connectivity" / ETIMEOUT hang from biting on devices where the default resolver misbehaves.
5. Unsets `LD_PRELOAD`. Termux's syscall shim must not be loaded when the glibc binary starts, or it crashes on an unversioned libc.so dependency.
6. Execs the binary. The wrapper passes claude's output through unchanged. claude itself may print a cosmetic "Native installation" startup notice if `~/.local/bin` is not yet on your PATH; it is harmless.

Force an immediate update check at any time:

```bash
claude --update-now
```

If any update step fails (network down, checksum mismatch, patchelf error), the wrapper prints a one-line warning to stderr and falls through to launch the cached binary, so a failed update should not interrupt your session.

### What the wrapper keeps on disk, and how to reset it

The wrapper stores its state alongside the binaries, in `~/.local/share/claude/versions/`:

- The current binary and the previous one, kept so a bad update can roll back without re-downloading. Each runs a few hundred megabytes (recent builds have been roughly 230 to 260 MB, and the size drifts release to release), so these two binaries are the bulk of Path A's disk use.
- `.verified`: the version last confirmed to launch on this device, so the launch test is skipped next time.
- `.blocklist`: versions that crashed on this device. A blocklisted version is never run or downloaded again.

If a version was blocklisted and you want the wrapper to try it again (for example after a Termux or glibc update that might have fixed it), delete the blocklist and relaunch:

```bash
rm ~/.local/share/claude/versions/.blocklist
```

### Updating Claude Code (Path A)

Automatic. The wrapper checks for new versions on launch (once per 24 hours, or immediately with `--update-now`). You don't run anything to update.

If you want to control update timing yourself, you can edit the stamp file's mtime or remove it (`rm ~/.local/share/claude/versions/.last-update-check`) and the next launch will check again.

### Upgrading from a pinned v2.x install

If you installed with an earlier version of this repo, you may be on the pinned npm install (Claude Code `2.1.112`, with the in-process auto-updater disabled). To move to the v2.9.0 architecture without losing your work, use the migration script:

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/migrate.sh -o migrate.sh
bash migrate.sh
```

Close any running `claude` sessions first. The script refuses to run while one is active, because replacing the binary under a live session would corrupt it.

What it does:

- Backs up `~/.claude`, `~/.claude.json`, and `~/.bashrc` to a timestamped folder before changing anything, and writes a `restore.sh` you can run to undo.
- Downloads, checksum-verifies, patches, and launch-tests the latest claude binary, then removes the old pinned install and drops in the auto-updating wrapper. The new binary must boot on this device before the old one is removed, so a release that crashes here (or any failure partway) leaves your existing install in place and usable.
- Merges your `~/.claude/settings.json` in place, preserving your existing hooks, permissions, and env. It does not overwrite your settings, and if that file is a symlink it follows the link instead of replacing it.

Preserved untouched: your chats and sessions, your login, and any custom agents, hooks, skills, or `CLAUDE.md`. Running `install.sh` on a pinned install detects it and points you here rather than overwriting anything.

### Uninstalling (Path A)

```bash
rm -f $PREFIX/bin/claude
rm -f ~/.local/bin/claude
rm -rf ~/.local/share/claude
rm -rf ~/.claude
# Optionally remove the recommended packages and glibc-runner if you want
# the disk back:
pkg uninstall -y glibc-runner patchelf-glibc glibc-repo
```

---

## Recommended Common Packages

If you said no to Q2 during the installer, or you want to add the packages later, the full list is:

```bash
pkg install git gh wget jq python openssh tree proot termux-api proot-distro make clang file xxd htop bat fzf -y
```

| Package | What it's for |
|---|---|
| `git` | Repo operations |
| `gh` | GitHub CLI (issues, PRs, releases) |
| `wget` | HTTP downloads (some scripts assume it; `curl` is already present) |
| `jq` | JSON parsing in scripts |
| `python` | Python scripting and tools |
| `openssh` | SSH client (and server, if you want it) |
| `tree` | Directory visualization |
| `proot` | Userspace `chroot`-like sandbox; used by `proot-distro` |
| `termux-api` | Device APIs (camera, GPS, TTS, fingerprint, battery); pair with the Termux:API companion app from F-Droid |
| `proot-distro` | Required for Path B (Ubuntu install). proot-distro is a Termux tool that runs full Linux distributions inside Termux via proot-based syscall translation. |
| `make` | Build automation |
| `clang` | C/C++ compiler |
| `file` | File-type identifier (`file path/to/x`) |
| `xxd` | Hex dump utility |
| `htop` | Interactive process monitor |
| `bat` | `cat` with syntax highlighting and paging |
| `fzf` | Fuzzy finder |

---

## Verification

After Path A install + first launch, you can confirm the architecture is in place:

```bash
# Wrapper exists at $PREFIX/bin/claude
ls -la $PREFIX/bin/claude

# Latest installed binary
ls $HOME/.local/share/claude/versions/

# Settings has autoUpdates:false (and no env.LD_PRELOAD)
cat $HOME/.claude/settings.json

# Wrapper resolves correctly via PATH (not claude's self-installed symlink)
command -v claude   # should print $PREFIX/bin/claude

# Version reports correctly through the wrapper
claude --version
```

For an automated pass that exercises a fixed claim set against your device, clone the repo and run the verify-claims script:

```bash
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
bash claude-code-android/tests/verify-claims.sh
```

Results are written to `tests/results/<your-device>-android<version>.txt`. Some checks are specific to the older v2.x install and will report SKIP on a v2.9.0 install; this is expected. The script is read-only and safe to re-run.

---

## Tested On

The canonical device compatibility matrix lives in the **[main README](../README.md#device-compatibility)**. As of the 2026-07-01 run I have verified Path A end to end on four devices:

- Google Pixel 10 Pro and Google Pixel 6, both Android 17, running the native linux-arm64 binary through the auto-updating wrapper.
- Motorola Moto G7 Power (Android 10) and Samsung Galaxy S7 (Android 8), which cannot run the native binary (it trips Android's seccomp filter on launch) and so stay on the pinned `2.1.112` install (`install-pinned.sh`). The Galaxy S7 needs the manual OAuth URL paste.

The pinned-install migration (`migrate.sh`) was verified on a Samsung Galaxy S26 Ultra (Android 16) on 2026-05-29. Path B and Path C are independent of the Path A architecture change. See the README for the full matrix and per-device notes.

[Submit a device report](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.yml) if you have tested on hardware not listed above.

---

## Path B: proot-distro Ubuntu

A full Ubuntu Linux environment inside Termux. Inside the Ubuntu guest, the Node.js `process.platform` property (Node.js's identifier of the host operating system, which some tools branch on) returns `'linux'` (same as on a PC), and the standard `/tmp`, `/etc`, glibc paths all work as expected. Claude Code installs via Anthropic's official `claude.ai/install.sh` script, no patching needed.

### When to use Path B

- You want a full Linux environment (apt, standard paths, /tmp works natively)
- You plan to run other Linux tools alongside Claude Code
- You prefer the upstream installer over the patched-binary approach

### Setup: Every Step, Verified

Tested on Pixel 10 Pro (Android 17) and Samsung Galaxy S26 Ultra (Android 16), verified 2026-05-16. Every command below is the exact sequence that worked in my testing, verified by hand on those devices.

**Step 1: Update Termux:**

```bash
pkg upgrade -y
```

Termux selects a mirror automatically. This updates all base packages including openssl and curl. **This step is required.** Without updated SSL libraries, the Claude Code installer returns 403.

> You may be asked about config files (like OpenSSL). On a fresh install, choose "install the package maintainer's version."

**Step 2: Install proot-distro:**

```bash
pkg install proot-distro -y
```

**Step 3: Install Ubuntu:**

```bash
proot-distro install ubuntu
```

Downloads an Ubuntu image (Ubuntu 25.10 / Questing Quokka at the time I tested; proot-distro may pull a newer release in the future). Approximately 55MB.

**Step 4: Enter Ubuntu:**

```bash
proot-distro login ubuntu
```

Your prompt changes to `root@localhost`. You are now inside a full Ubuntu Linux environment.

> The warning `can't sanitize binding "/proc/self/fd/1"` appears during login. It is harmless; stdout works correctly.

**Step 5: Update Ubuntu packages:**

```bash
apt update && apt upgrade -y
```

**This step is required.** Fresh Ubuntu packages are not up to date. Without this, the Claude Code native installer returns 403 because the SSL/curl libraries cannot reach Anthropic's CDN.

**Step 6: Install Claude Code:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

If you prefer to inspect the script before running it:

```bash
curl -fsSL https://claude.ai/install.sh -o install.sh && less install.sh && bash install.sh
```

Native installer. No Node.js required. Installs to `~/.local/bin/claude`.

**Step 7: Add to PATH:**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

**Step 8: Verify:**

```bash
claude --version
```

Should print the installed version number. The native installer always fetches the latest release.

**Step 9: Launch:**

```bash
claude
```

On first launch, claude will trigger OAuth and try to open a browser. Behavior varies by Android version (verified 2026-05-16):

- **Android 10+** (Pixel 10 Pro, Pixel 6, Moto G7 Power tested): browser auto-opens (Chrome on my test devices). Sign in there and return to the terminal.
- **Android 8 and possibly 9** (Galaxy S7 tested): browser does NOT auto-open. Copy the URL from terminal output and paste it into your phone's browser manually.

See [FAQ: Claude prints a URL but my browser doesn't open](faq.md#claude-prints-a-url-but-my-browser-doesnt-open).

### Path B trade-offs

| | Path A (native Termux) | Path B (proot-distro Ubuntu) |
|---|---|---|
| Setup time | 5-10 min | ~10-15 min |
| Disk usage | ~280 MB base (~480 MB with recommended packages) | ~2 GB |
| Install method | Patched linux-arm64 binary | Anthropic installer (curl) |
| Updates | Wrapper auto-checks once per day | Re-run upstream installer manually |
| process.platform | linux (via patched binary) | linux (native to Ubuntu) |
| Best for | Smallest install, auto-updates | Full Linux environment |

### Path B notes

- **Samsung One UI 8 users:** In my testing, Termux backgrounded under One UI 8 can slow down the proot session noticeably. Keep Termux in the foreground or split-screen for best performance. See also proot-distro issue [#567](https://github.com/termux/proot-distro/issues/567) if you want to track this upstream.
- **To re-enter Ubuntu after closing Termux:** just run `proot-distro login ubuntu` again. Your Ubuntu environment persists between sessions.

### Verified Path B configuration

| Component | Version |
|-----------|---------|
| proot-distro | 4.38.0 |
| Guest OS | Ubuntu 25.10 (Questing Quokka) |
| Claude Code | Current version (native installer fetches latest) |
| Kernel | 6.12.30 (Android 16) |

---

*Path B last verified: 2026-05-16*

---

## Path C: AVF Linux VM (experimental)

Path C uses the Android Virtualization Framework that ships in Android 16 and later on supported devices. It boots a Debian VM with a real Linux kernel; the Claude Code install inside the VM uses Anthropic's official installer the same way Path B does.

Prerequisites for Path C: a Pixel 6 or later (support on other devices varies; once you have enabled Developer options in the steps below, you can confirm support by looking for the **Linux development environment** toggle there), Android 16 or later.

Outline:

1. Settings > About phone > tap **Build number** 7 times to enable Developer options.
2. Settings > System > Developer options > **Linux development environment** > toggle on.
3. Open the Terminal app that appears on the home screen. Accept the Debian image download (several hundred megabytes; use WiFi).
4. When the prompt shows `droid@debian:~$`, install Claude Code: `curl -fsSL https://claude.ai/install.sh | bash`, then `export PATH="$HOME/.local/bin:$PATH"` (also append to `~/.bashrc`), then `claude`.

For everything else (Memory size, Display resolution, Keep awake, Recovery, ADB hardware bridge (ADB, Android Debug Bridge, is a command-line tool for communicating with a connected Android device), known issues), see the dedicated guide: **[docs/avf-guide.md](avf-guide.md)**. Path C re-verified on Pixel 6 and Pixel 10 Pro running Android 17 on 2026-05-26.

---

## Advanced Usage

These features have been verified working on Android. They go beyond basic setup.

### Cron-triggered headless sessions

Claude Code can run autonomously via cron: no terminal, no user interaction.

```bash
pkg install cronie
crond -s  # Start the cron daemon (no systemd, must start manually)

# Example: run a daily code review at 9am
echo "0 9 * * * cd ~/repos/your-project && claude -p 'review recent changes and summarize' >> ~/cron-output.log 2>&1" | crontab -
```

Your cron script must set environment variables explicitly:
```bash
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:$PATH
cd ~/repos/your-project  # CLAUDE.md loads from the working directory
claude -p "your prompt here"
```

**Sandboxing cron sessions:** Headless sessions should not have web access. Use `--tools` and `--disallowedTools` to lock a cron job to local-only operations:

```bash
claude -p "your prompt here" \
  --tools "Read,Write,Edit,Bash,Glob,Grep" \
  --disallowedTools "WebFetch,WebSearch,Bash(curl:*),Bash(wget:*)"
```

Both flags are needed because `--tools` controls which Claude Code tools are available, but an agent with Bash access can still run `curl` or `wget` as shell commands. The `--disallowedTools` flag with `Bash(curl:*)` and `Bash(wget:*)` closes that gap. The result: full local file and shell capability, zero network access.

To persist crond across reboots, add `crond -s` to `~/.bashrc` or use Termux:Boot.

### Session resume

Resume a previous conversation:
```bash
claude --resume <session-id>
```

Session IDs are shown in `--output-format json` output and stored in `~/.claude/projects/`.

### Structured output

For scripting and automation:
```bash
claude -p "your prompt" --output-format json     # Full JSON with cost, tokens, session ID
claude -p "your prompt" --output-format stream-json --verbose  # Streaming JSON events
```

### Context management

Inside a running session, use `/compact` to compress the conversation context. This is useful during long sessions to stay within the context window.

---

## Why v2.9.0

The earlier Path A install (v2.x) pinned `@anthropic-ai/claude-code@2.1.112`, the last upstream version that shipped a bundled JavaScript entry point. Versions 2.1.113+ switched to a platform-native binary distribution that excludes android-arm64; on native Termux those versions installed but `claude` exited immediately with `Error: claude native binary not installed`. The pin was defended with `chmod -R a-w` on the install directory plus `DISABLE_AUTOUPDATER=1` in shell env and `~/.claude/settings.json`. Tracked upstream at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270).

The v2.9.0 Path A install drops the pin and runs the same linux-arm64 native binary that PC users run, by patching the binary's ELF interpreter via Termux's `glibc-runner` and `patchelf-glibc`. The approach was originally described in [a comment on the upstream issue](https://github.com/anthropics/claude-code/issues/50270#issuecomment-4467292215). This repo's `install.sh` adapts it with empirical verification, an auto-updating wrapper, and the interactive prompts. The earlier pinned approach remains available as an opt-in for a minimal install or for older devices that cannot run the native binary: [`install-pinned.sh`](../install-pinned.sh) installs `2.1.112` with no binary patching and no auto-updating wrapper.

That patching is a compatibility shim, not native support. Anthropic ships no Android build, so Path A runs only because the linux-arm64 binary is made to load through Termux's glibc-runner. The real fix is upstream: adding an official Android build would need either a `bun` `android-arm64` target or a static musl build. Until that ships, Path A relies on the patching step.

Path B and Path C were unchanged by the v2.9.0 work; both already install the latest claude via Anthropic's official installer inside their respective Linux environments.
</content>
