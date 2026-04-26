# Installing Claude Code on Android

A complete, reproducible guide to running Claude Code on an aarch64 Android device using Termux. Every command has been tested on real hardware. Follow these steps in order and it will work.

---

## Prerequisites

Before you begin, confirm you have the following:

| Component | Requirement |
|-----------|-------------|
| **Architecture** | aarch64 (64-bit ARM); run `uname -m` to verify. If it returns `armv7l` or `armv8l`, Claude Code will not work on your device |
| **Device** | aarch64 Android device (ARM64) |
| **OS** | Android 14+ |
| **Kernel** | Varies by Android version; use `uname -r` to check (Android 14/15 use 5.10–6.6, Android 16 uses 6.12) |
| **Terminal** | [Termux from F-Droid](https://f-droid.org/en/packages/com.termux/), **not** the Play Store version, which is outdated and will fail |
| **Subscription** | Claude Pro, Max, Team, Enterprise, or Console account (provides the API access Claude Code requires) |
| **Network** | Active internet connection (Claude Code streams from Anthropic's API) |
| **Termux:API** | Both the `termux-api` package (`pkg install termux-api`) and the [Termux:API companion app from F-Droid](https://f-droid.org/en/packages/com.termux.api/) are required for device features (battery, camera, TTS, SMS, GPS, sensors) |

> **Permission tip:** Only grant the Termux:API permissions your workflow requires. You can deny SMS, Contacts, Call Log, Camera, Microphone, and Location and still use Claude Code normally. See the [Security Model](security-model.md) for what each permission exposes.

> **Warning:** The Play Store version of Termux has not been updated since 2020 and does not support current package repositories. You must use F-Droid or install the `.apk` directly from the [Termux GitHub releases](https://github.com/termux/termux-app/releases).

---

## Choose Your Path

This guide has two installation paths. Pick one before you start.

| | Path A: Native Termux | Path B: proot-distro Ubuntu |
|---|---|---|
| **Best for** | Quick setup, experienced users | Full Linux environment, fewer workarounds |
| **Setup time** | ~2 min (experienced) | ~10-15 min (experienced) |
| **Ongoing maintenance** | Ripgrep fix breaks on every update | Just update normally |
| **Install method** | npm | Native installer (curl) |
| **Node.js required** | Yes (v25+) | No |

**New to this?** Start with Path B -- it has fewer things that can go wrong. Allow 30-45 minutes for your first install including Termux and F-Droid setup.

**Want the fastest setup?** Use Path A.

[Jump to Path A](#step-1-install-dependencies) · [Jump to Path B](#path-b-proot-distro-ubuntu)

**Have a Pixel 6+ on Android 16?** There is a third option -- Path C uses the Android Virtualization Framework (AVF) to run a real Linux VM with zero workarounds. See the [AVF Guide](avf-guide.md) for setup.

---

## Why This Is Hard

Running Claude Code on Android means solving problems that don't exist on desktop Linux. The full explanation is in the [README](../README.md#why-this-is-hard). The key points:

1. **`/tmp` isn't writable.** Claude Code needs it, Android doesn't provide it. Path A fixes this with a proot bind mount. Path B avoids it entirely (Ubuntu has native `/tmp`).
2. **Node.js v24 may hang on ARM64.** Use v25+ (Termux ships this by default). The hang is specific to v24, not Termux generally. v25 resolves it. If you encounter it, try setting `CLAUDE_CODE_TMPDIR` (see Step 4) or use Path B, where this constraint does not apply.
3. **ripgrep binary missing for ARM64 Android.** Path A needs a symlink fix. Path B doesn't need it.

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

This installs Node.js v25+, git, curl, proot, ripgrep, termux-api, and jq. Node.js runs Claude Code, git is needed for repository operations, curl is used during authentication flows, proot handles the `/tmp` bind mount at launch, ripgrep is required for Claude Code's Grep and Glob tools to work on ARM64, termux-api ships the device-API CLIs paired with the companion app, and jq is used for safely merging `~/.claude/settings.json` in Step 5.

---

## Step 2: Set TMPDIR

```bash
export TMPDIR=$PREFIX/tmp
echo 'export TMPDIR=$PREFIX/tmp' >> ~/.bashrc   # Make it permanent
```

The `export` only lasts this session. The `echo` line makes it permanent across reboots.

**This is critical.** Termux does not set `TMPDIR` by default. Without it, npm has no writable temporary directory. The install will either fail silently, produce a corrupted installation, or appear to succeed while leaving Claude Code unable to start. This single missing environment variable is the most common point of failure in Termux Node.js setups.

`$PREFIX` resolves to `/data/data/com.termux/files/usr`. The `tmp` directory inside it is writable by Termux processes.

---

## Step 3: Install Claude Code (pinned)

```bash
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@2.1.112
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
```

This installs Claude Code globally via npm at version **2.1.112**, the last upstream version that ships the bundled `cli.js` JavaScript entry point. Versions 2.1.113 and later switched to a platform-native binary distribution that excludes android-arm64; on native Termux those versions install but `claude` exits immediately with `Error: claude native binary not installed`. Tracked at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270).

The `DISABLE_AUTOUPDATER=1` env disables Claude Code's in-process auto-updater that would otherwise re-fetch `latest` on a timer and clobber the pin **inside running sessions**. The `chmod -R a-w` is the load-bearing belt-and-braces; without it, the running session's updater silently overwrites the install dir even with the env var set.

> **Note:** Anthropic offers a native installer (`curl -fsSL https://claude.ai/install.sh | bash`) for supported platforms. It does not currently support android-arm64; use the pinned npm install above for Path A. The native installer works correctly in Path B (proot-distro Ubuntu) where `process.platform === 'linux'` matches a published native binary.

> **Upgrade later** (when upstream restores android-arm64 support, watch [#50270](https://github.com/anthropics/claude-code/issues/50270)):
>
> ```bash
> chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
> npm install -g @anthropic-ai/claude-code@<new-version>
> chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
> ```

---

## Step 4: Launch Claude Code (Required)

Claude Code hardcodes `/tmp` for runtime state. The fix is `proot`, a userspace path remapper that requires no root privileges. It intercepts system calls and makes `/tmp` point to Termux's writable tmp directory.

proot was installed in Step 1.

Launch:

```bash
proot -b $PREFIX/tmp:/tmp claude
```

This binds Termux's writable tmp directory to `/tmp` (so Claude Code's `/tmp` references work) and runs the `claude` symlink installed by npm in Step 3. No root. No containers. No virtualization.

> **Alternative to the bind mount:** If you prefer not to use proot for this workaround, you can set the `CLAUDE_CODE_TMPDIR` environment variable to any writable directory:
>
> ```bash
> mkdir -p ~/tmp
> echo 'export CLAUDE_CODE_TMPDIR=$HOME/tmp' >> ~/.bashrc
> source ~/.bashrc
> ```
>
> This tells Claude Code to use that directory for temporary files instead of the default `/tmp`. No proot required. Add this before the `claude` launch command in your startup alias. Note: this only redirects Claude's own temp files; other tools that hardcode `/tmp` may still fail. The proot approach above is more comprehensive.

On first launch, Claude Code will prompt you to authenticate. A URL will appear in your terminal; open it in your phone's browser to complete OAuth. If authentication fails, see the [OAuth troubleshooting entry](troubleshooting.md#oauth--authentication-fails-on-first-launch).

---

## Step 5: Create the Alias

Add this alias to your `~/.bashrc`. Use `claude-android` every time; bare `claude` skips the proot bind mount and `/tmp`-touching operations will fail:

```bash
echo "alias claude-android='proot -b \$PREFIX/tmp:/tmp claude'" >> ~/.bashrc
echo 'export DISABLE_AUTOUPDATER=1' >> ~/.bashrc
source ~/.bashrc
```

Also add `"env": {"DISABLE_AUTOUPDATER": "1"}` to `~/.claude/settings.json` so the auto-updater stays disabled inside running sessions, not just at shell launch.

Then launch with:

```bash
claude-android
```

---

## Verification

After completing the steps above, run these commands to confirm your setup matches the verified configuration:

```bash
# Node.js: must be v25+
node -v

# npm: should be v11+
npm -v

# Claude Code: confirms the binary is installed and on PATH
claude --version

# proot: confirms proot is available
proot --help 2>&1 | head -1

# TMPDIR: must be set to a writable path
echo $TMPDIR

# /tmp bind: confirms proot remapping works
proot -b $PREFIX/tmp:/tmp ls /tmp
```

Expected output pattern:

```
v25.x.x
11.x.x
2.x.x (Claude Code)
Usage: proot [...]
/data/data/com.termux/files/usr/tmp
[contents of tmp directory]
```

If `node -v` shows v24 or below, upgrade with `pkg upgrade nodejs`. If `echo $TMPDIR` is empty, add `export TMPDIR=$PREFIX/tmp` to your `~/.bashrc` and source it.

For a full automated verification, clone this repo and run:

```bash
git clone https://github.com/ferrumclaudepilgrim/claude-code-android.git
bash claude-code-android/tests/verify-claims.sh
```

This tests all documentation claims against your actual device. Results are saved to `tests/results/<your-device>.txt`. Submit yours via PR to help build the compatibility database.

---

## Tested On

Community-reported working configurations:

| Device | Android Version | Kernel | Termux Source | Node.js | Status |
|--------|----------------|--------|---------------|---------|--------|
| Samsung Galaxy S26 Ultra | Android 16 | 6.12.30 | F-Droid | v25.8.1 | Path A + B verified |
| Google Pixel 10 Pro | Android 16 | n/a | F-Droid | v25.8.1 | Path A + B verified |
| Samsung Galaxy S23+ | Android 15 | n/a | F-Droid | v25.8.1 | Path B verified |

Three devices verified across two Android versions (15 and 16), two manufacturers (Samsung and Google). Auth required manual URL copy-paste on all devices (expected for Path B). Expected to work on Android 14+ with any aarch64 device. [Submit a device report](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) if you've tested on different hardware.

---

## Keeping It Running

### Updating Claude Code (Path A)

**Do not run `npm update -g @anthropic-ai/claude-code`.** That pulls `latest` which is currently 2.1.114 (broken on android-arm64). Stay on the pinned 2.1.112 until upstream restores android-arm64 support; track [#50270](https://github.com/anthropics/claude-code/issues/50270).

To intentionally bump to a specific newer version once one is published as working on android-arm64:

```bash
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@<new-version>
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
claude --version    # confirm
```

The chmod dance is required because Step 3 locked the install dir read-only against the auto-updater. You have to restore write permission before any reinstall.

After updating, the ripgrep symlink breaks (Claude Code replaces its vendor directory). The `CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1` env (added by `install.sh` in the original install) makes Claude Code use the system `rg` instead of its bundled binary, so this issue does not recur. If for some reason you need the symlink approach instead, restore it manually:

```bash
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
VENDOR_DIR="$(dirname "$(command -v claude)")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
mkdir -p "$VENDOR_DIR/arm64-android"
ln -sf "$(command -v rg)" "$VENDOR_DIR/arm64-android/rg"
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
```

### Durable ripgrep fix (recommended)

Instead of the symlink (which breaks on every update), set this environment variable:

```bash
echo 'export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1' >> ~/.bashrc
source ~/.bashrc
```

With `CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1`, Claude Code uses the system-installed ripgrep (`pkg install ripgrep`) instead of its bundled binary. This survives Claude Code updates -- no re-symlinking required. The symlink approach above still works but must be re-applied after every `npm update`.

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

Remove the alias and `DISABLE_AUTOUPDATER` line from `~/.bashrc` if you added them. Remove `~/.claude/` to clear all configuration.

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

On first launch, authentication requires manual URL copy/paste. No browser auto-opens inside proot-distro. Copy the URL from the terminal, open it in your Android browser, authenticate, then return to the terminal.

### Path B trade-offs

| | Path A (Native Termux) | Path B (proot-distro Ubuntu) |
|---|---|---|
| Setup time | ~2 min (experienced) | ~10-15 min (experienced) |
| Disk usage | Minimal | ~2 GB for Ubuntu rootfs + Claude Code |
| /tmp workaround | Required (proot bind mount) | Not needed |
| ripgrep fix | Required (symlink, breaks on update) | Not needed |
| Install method | npm | Native installer (curl) |
| Node.js required | Yes (v25+) | No |
| Auth flow | Browser auto-opens | Manual URL copy/paste |
| Ongoing maintenance | Re-fix ripgrep after every update | Just update normally |
| Best for | Quick setup, light usage | Full Linux environment, fewer workarounds |

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

*Last verified: 2026-04-18*

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

**Path A users:** Cron jobs need the same proot wrapper that interactive sessions use. Replace bare `claude -p` with `proot -b $PREFIX/tmp:/tmp claude -p` in your crontab entries. Without this, Claude Code cannot write to `/tmp` and will fail silently.

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
