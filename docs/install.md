# Installing Claude Code on Android

A complete, reproducible guide to running Claude Code on an aarch64 Android device using Termux. Every command in this guide has been tested on real hardware. Follow these steps in order; this is the sequence that has worked across the four lab devices verified on 2026-05-16. Other devices and Android versions may behave differently -- if something breaks for you, please [open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=bug_report.md).

---

## Prerequisites

Before you begin, confirm you have the following:

| Component | Requirement |
|-----------|-------------|
| **Architecture** | aarch64 (64-bit ARM); run `uname -m` to verify. If it returns `armv7l` or `armv8l`, Claude Code will not work on your device |
| **Device** | aarch64 Android device (ARM64) |
| **OS** | Android 8+ (Android 8 / 9 have OAuth caveats -- see FAQ) |
| **Kernel** | Varies by Android version; use `uname -r` to check (Android 14/15 use 5.10–6.6, Android 16 uses 6.12) |
| **Terminal** | [Termux from F-Droid](https://f-droid.org/en/packages/com.termux/), **not** the Play Store version, which is outdated and will fail |
| **Subscription** | Claude Pro, Max, Team, Enterprise, or Console account (provides the API access Claude Code requires) |
| **Network** | Active internet connection (Claude Code streams from Anthropic's API) |
| **Termux:API** | Both the `termux-api` package (`pkg install termux-api`) and the [Termux:API companion app from F-Droid](https://f-droid.org/en/packages/com.termux.api/) are required for device features (battery, camera, TTS, SMS, GPS, sensors) |

> **Permission tip:** Only grant the Termux:API permissions your workflow requires. You can deny SMS, Contacts, Call Log, Camera, Microphone, and Location and still use Claude Code normally. See the [Security Model](security-model.md) for what each permission exposes.

> **Termux:API source-matching:** The `termux-api` package (installed via `pkg install termux-api`) and the Termux:API companion app **must come from the same source** -- both F-Droid or both GitHub releases. Mixing sources causes silent permission failures that are difficult to diagnose. Without both the package and the app, Termux:API calls fail silently.

> **Warning:** The Play Store version of Termux has not been updated since 2020 and does not support current package repositories. You must use F-Droid or install the `.apk` directly from the [Termux GitHub releases](https://github.com/termux/termux-app/releases).

---

## Choose Your Path

This guide covers three installation paths. Pick one before you start.

| | Path A: Native Termux | Path B: proot-distro Ubuntu | Path C: AVF Linux VM |
|---|---|---|---|
| **Best for** | Smallest install, light usage | Most users (full Linux env) | Experimenters with Pixel 6+ |
| **Setup time** | ~2 min (experienced) | ~10-15 min (experienced) | ~20 min (experienced) |
| **Disk usage** | ~50 MB | ~2 GB | ~2 GB |
| **Ongoing maintenance** | None | Just update normally | Just update normally |
| **Install method** | npm (pinned to 2.1.112) | Anthropic installer (latest) | Anthropic installer (latest) |
| **Node.js required** | Yes (v25+) | No | No |
| **Device support** | Any aarch64 Android 8+ (Android 8 / 9 have OAuth caveats -- see FAQ) | Any aarch64 Android 8+ (Android 8 / 9 have OAuth caveats -- see FAQ) | Pixel 6+ Android 16+ |
| **Stability** | Stable | Stable | Experimental |

**Need help deciding?** Path B is the recommendation for most users -- it has the fewest things that can go wrong. Allow 30-45 minutes for your first install including Termux and F-Droid setup.

**Want the smallest footprint or already familiar with Termux?** Path A is fine.

**Have a Pixel 6+ on Android 16+ and want a real Linux kernel?** Path C uses the Android Virtualization Framework (AVF). See **[AVF Guide](avf-guide.md)** for setup, VM configuration, ADB hardware bridge, and limitations.

[Jump to Path A](#step-1-install-dependencies) · [Jump to Path B](#path-b-proot-distro-ubuntu) · [Jump to Path C (avf-guide.md)](avf-guide.md)

---

## Environment Reference

Key paths and versions for a working installation:

- **Architecture:** aarch64 (ARM64)
- **Kernel:** Varies by Android version; verify with `uname -r` (Android 14/15: 5.10–6.6, Android 16: 6.12)
- **Shell:** Termux
- **Home:** `/data/data/com.termux/files/home`
- **Prefix:** `/data/data/com.termux/files/usr`
- **Node.js:** v25+
- **proot:** 5.1.107+

There is no root access. There is no systemd. There is no `/tmp` in the way most Unix programs expect. The filesystem paths are deeply nested inside Android's app sandbox.

---

## Step 1: Install Dependencies

Open Termux and run:

```bash
pkg install nodejs git curl proot ripgrep termux-api jq -y
```

This installs Node.js v25+, git, curl, proot, ripgrep, termux-api, and jq. Node.js runs Claude Code. git is for repository operations. curl is used during authentication flows and general HTTP. ripgrep makes Claude Code's Grep and Glob tools work on ARM64 (paired with `CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1` in your `~/.bashrc`; see the Grep/Glob fix section). termux-api ships the device-API CLIs paired with the companion app. proot is useful for wrapping tools that hardcode `/tmp`. jq is useful for editing JSON config files.

> **MVP-only footprint:** A minimum Path A install requires only `nodejs` (verified 2026-05-16 across Pixel 10 Pro, Pixel 6, Moto G7 Power, Galaxy S7 -- bare `claude` launches without proot on the pinned 2.1.112 build). The full list above is the recommended kit for general use -- git/curl/proot/jq/ripgrep/termux-api add features and convenience but are not structurally required to launch claude.

---

## Step 2: Set TMPDIR

```bash
export TMPDIR=$PREFIX/tmp
echo 'export TMPDIR=$PREFIX/tmp' >> ~/.bashrc   # Make it permanent
```

The `export` only lasts this session. The `echo` line makes it permanent across reboots.

**This is critical.** Termux does not set `TMPDIR` by default. Without it, npm has no writable temporary directory. The install will either fail silently, produce a corrupted installation, or appear to succeed while leaving Claude Code unable to start. This missing environment variable is a common point of failure in Termux Node.js setups.

`$PREFIX` resolves to `/data/data/com.termux/files/usr`. The `tmp` directory inside it is writable by Termux processes.

---

## Step 3: Install Claude Code (pinned)

```bash
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@2.1.112
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
```

This installs Claude Code globally via npm at version **2.1.112**, the last upstream version that ships the bundled `cli.js` JavaScript entry point. Versions 2.1.113 and later switched to a platform-native binary distribution that excludes android-arm64; on native Termux those versions install but `claude` exits immediately with `Error: claude native binary not installed`. Tracked at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270).

The `DISABLE_AUTOUPDATER=1` env disables Claude Code's in-process auto-updater that would otherwise re-fetch `latest` on a timer and clobber the pin **inside running sessions**. The `chmod -R a-w` is the load-bearing belt-and-braces; without it, the running session's updater silently overwrites the install dir even with the env var set.

> **Note:** Anthropic offers a native installer (`curl -fsSL https://claude.ai/install.sh | bash`) for supported platforms. It does not include an android-arm64 native binary (upstream [#50270](https://github.com/anthropics/claude-code/issues/50270)); use the pinned npm install above for Path A. The native installer works correctly in Path B (proot-distro Ubuntu) where `process.platform === 'linux'` matches a published native binary.

> **Upgrade later** (when upstream restores android-arm64 support, watch [#50270](https://github.com/anthropics/claude-code/issues/50270)):
>
> ```bash
> chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
> npm install -g @anthropic-ai/claude-code@<new-version>
> chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
> ```

---

## Step 4: Launch Claude Code

```bash
claude
```

That is the whole command. The `chmod -R a-w` from Step 3 is what keeps subsequent launches pinned to 2.1.112 -- the in-process auto-updater cannot replace the read-only install directory, so every launch finds the same working binary. Verified empirically across Pixel 10 Pro (Android 17 Beta), Pixel 6 (Android 13), Moto G7 Power (Android 10), Galaxy S7 (Android 8).

On first launch, claude will trigger OAuth and try to open a browser. Behavior varies by Android version:

- **Android 10+** (Pixel 10 Pro, Pixel 6, Moto G7 Power tested 2026-05-16): browser auto-opens to Chrome. Sign in there and return to the terminal.
- **Android 8 and possibly 9** (Galaxy S7 tested 2026-05-16): browser does NOT auto-open. Copy the URL from terminal output and paste it into your phone's browser manually.

See [FAQ: Claude prints a URL but my browser doesn't open](faq.md#claude-prints-a-url-but-my-browser-doesnt-open).

---

## Verification

After completing the steps above, run these commands to confirm your setup matches the verified configuration:

```bash
# Node.js: must be v25+
node -v

# Claude Code: confirms the binary is installed and on PATH
claude --version

# Install dir is locked read-only (the load-bearing auto-updater protection)
ls -la "$PREFIX/lib/node_modules/@anthropic-ai/claude-code" | head -1
```

Expected output pattern:

```
v25.x.x
2.1.112 (Claude Code)
dr-x------ ...
```

If `claude --version` reports a 2.1.113+ version on native Termux, the auto-updater clobbered the pin (see [Recovery from the April 18 upstream regression](#recovery-from-the-april-18-upstream-regression) below).

For a full automated verification, clone this repo and run:

```bash
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
bash claude-code-android/tests/verify-claims.sh
```

This tests all documentation claims against your actual device. Results are saved to `tests/results/<your-device>.txt`. Submit yours via PR to help build the compatibility database.

---

## Tested On

The canonical device compatibility matrix lives in the **[main README](../README.md#device-compatibility)**. As of 2026-05-16, verified end-to-end across:

- Samsung Galaxy S26 Ultra (Android 16) -- Path A + B
- Google Pixel 10 Pro (Android 17) -- Path A + B + ADB self-connect
- Google Pixel 6 (Android 13) -- Path A + B
- Motorola Moto G7 Power (Android 10) -- Path A + B
- Samsung Galaxy S7 SM-G930P (Android 8) -- Path A + B (browser does not auto-open for OAuth; see [FAQ](faq.md#claude-prints-a-url-but-my-browser-doesnt-open))
- Samsung Galaxy S23+ (Android 15) -- Path B
- Pixel 10 Pro AVF guest (Android 16) -- Path C (experimental)

Test results per device live in **[`tests/results/`](../tests/results/)**. [Submit a device report](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) if you've tested on hardware not listed above.

---

## Keeping It Running

### Recovery from the April 18 upstream regression

If your Path A install was working and now `claude` prints `Error: claude native binary not installed`, or `claude --version` reports a 2.1.113+ version on native Termux: the in-process auto-updater pulled a newer version that has no android-arm64 build (tracked at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270)). Fix:

```bash
# Restore write permission, reinstall the pinned version, lock it back down
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/ 2>/dev/null
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@2.1.112
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
echo 'export DISABLE_AUTOUPDATER=1' >> ~/.bashrc
claude --version    # should print 2.1.112 (Claude Code)
```

Or rerun [install.sh](../install.sh) -- it does this idempotently.

The `chmod -R a-w` is load-bearing. Without it, the in-process auto-updater can re-fetch latest inside a running session and clobber the pin minutes after you fix it. The `DISABLE_AUTOUPDATER=1` env var alone is belt-and-braces; the chmod is what actually prevents the write.

**Path B users do not need this recovery.** Inside proot-Ubuntu, `process.platform` reports `linux` and `process.arch` reports `arm64`, which matches Anthropic's `linux-arm64` native binary. Path B installs the latest version cleanly. If the regression is a deal-breaker, Path B is the cleaner answer.

### Updating Claude Code (Path A)

**Do not run `npm update -g @anthropic-ai/claude-code`.** That pulls `latest`, which as of 2026-05-16 is 2.1.143 -- still broken on android-arm64 (Path A native Termux). Stay on the pinned 2.1.112 for Path A until upstream restores android-arm64 support; track [#50270](https://github.com/anthropics/claude-code/issues/50270). Path B users inside proot-Ubuntu get the latest version cleanly because the glibc Linux binary is unaffected by the android-arm64 bionic build issue.

To intentionally bump to a specific newer version once one is published as working on android-arm64:

```bash
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@<new-version>
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
claude --version    # confirm
```

The chmod dance is required because Step 3 locked the install dir read-only against the auto-updater. You have to restore write permission before any reinstall.

### Enabling Grep and Glob tools

Claude Code's Grep and Glob tools rely on a bundled `ripgrep` binary that is not published for android-arm64. To make them work, install system ripgrep and tell Claude Code to use it:

```bash
pkg install ripgrep -y
echo 'export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1' >> ~/.bashrc
source ~/.bashrc
```

One-time. Persists across Claude Code updates.

### Updating Termux packages

```bash
pkg upgrade
```

This updates proot, Node.js, and other dependencies. After a Node.js major version upgrade, verify Claude Code still launches.

### Uninstalling

```bash
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/ 2>/dev/null
npm uninstall -g @anthropic-ai/claude-code
```

The `chmod -R u+w` is required because Step 3 locked the install dir read-only; npm cannot remove read-only files without it.

If you customized your shell with a `claude-android` alias or `DISABLE_AUTOUPDATER` export from an earlier version of this guide, remove those lines from `~/.bashrc`. Remove `~/.claude/` to clear all configuration.

---

## Path B: proot-distro Ubuntu

A full Ubuntu Linux environment inside Termux. No `/tmp` workaround. No ripgrep fix. No npm. Claude Code thinks it's on a normal Linux computer.

### When to use Path B

- You want a full Linux environment (apt, standard paths, /tmp works natively)
- You plan to run other Linux tools alongside Claude Code
- You prefer the native installer over npm
- You want fewer things that break on updates

### Setup: Every Step, Verified

Tested on Pixel 10 Pro and Samsung Galaxy S26 Ultra, both Android 16. Every command is the exact sequence that works.

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

Downloads Ubuntu 25.10 (Questing Quokka), approximately 55MB.

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

- **Android 10+** (Pixel 10 Pro, Pixel 6, Moto G7 Power tested): browser auto-opens to Chrome. Sign in there and return to the terminal.
- **Android 8 and possibly 9** (Galaxy S7 tested): browser does NOT auto-open. Copy the URL from terminal output and paste it into your phone's browser manually.

See [FAQ: Claude prints a URL but my browser doesn't open](faq.md#claude-prints-a-url-but-my-browser-doesnt-open).

### Path B trade-offs

| | Path A (Native Termux) | Path B (proot-distro Ubuntu) |
|---|---|---|
| Setup time | ~2 min (experienced) | ~10-15 min (experienced) |
| Disk usage | Minimal | ~2 GB for Ubuntu rootfs + Claude Code |
| /tmp workaround | Not needed (bare `claude` launches without it on 2.1.112) | Not needed |
| Grep/Glob fix | One-time `CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1` in `~/.bashrc` | Not needed |
| Install method | npm (pinned to 2.1.112) | Native installer (curl) |
| Node.js required | Yes (v25+) | No |
| Auth flow | Auto-opens on Android 10+; manual URL copy on Android 8 / 9 | Auto-opens on Android 10+; manual URL copy on Android 8 / 9 |
| Ongoing maintenance | None | Just update normally |
| Best for | Quick setup, light usage | Full Linux environment |

**Why Path B often works when Path A doesn't:** Inside proot-distro Ubuntu, Claude
Code reports `process.platform === "linux"`. In native Termux, it reports `"android"`.
Many npm packages and Claude Code's own bundled tools (including ripgrep) branch on
this value. Tool failures, unresolved binary paths, and unexpected behavior in native
Termux may resolve cleanly inside the Ubuntu guest, not because the hardware changed,
but because the runtime identity did.

### Path B notes

- **Samsung One UI 8 users:** There is a known performance regression when Termux is backgrounded (proot-distro issue [#567](https://github.com/termux/proot-distro/issues/567)). Keep Termux in the foreground or split-screen for best performance.
- **You cannot run proot-distro from inside Claude Code** if Claude Code was launched with `proot -b`. proot-distro detects nesting and refuses. Run proot-distro commands from a separate Termux session.
- **To re-enter Ubuntu after closing Termux:** just run `proot-distro login ubuntu` again. Your Ubuntu environment persists between sessions.

### Verified Path B configuration

| Component | Version |
|-----------|---------|
| proot-distro | 4.38.0 |
| Guest OS | Ubuntu 25.10 (Questing Quokka) |
| Claude Code | Current version (native installer fetches latest) |
| Kernel | 6.12.30 (Android 16) |

---

*Last verified: 2026-05-16*

---

## Advanced Usage

These features have been verified working on Android. They go beyond basic setup.

### Cron-triggered headless sessions

Claude Code can run autonomously via cron -- no terminal, no user interaction.

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
export TMPDIR=$PREFIX/tmp
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
