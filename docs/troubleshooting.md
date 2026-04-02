# Troubleshooting Claude Code on Android

This guide covers problems specific to running Claude Code on **Android 14+ with Termux** (aarch64/ARM64). Each entry starts with the error you see, then the fix, then the explanation.

If you haven't installed yet, see [INSTALL.md](install.md) first.

---

## Table of Contents

- [Claude Code hangs on startup](#claude-code-hangs-on-startup)
- [Unsupported architecture: armhf](#unsupported-architecture-armhf)
- [Claude Code won't start, no error](#claude-code-wont-start-no-error)
- [OAuth / authentication fails on first launch](#oauth--authentication-fails-on-first-launch)
- [proot-distro issues](#proot-distro-issues)
- [Node.js v24 hangs](#nodejs-v24-hangs)
- [Process killed randomly](#process-killed-randomly)
- [EMFILE errors](#emfile-errors)
- [npm install fails silently](#npm-install-fails-silently)
- [Grep/Glob/slash commands fail with ENOENT](#grepglobslash-commands-fail-with-enoent)
- [Custom agents fail to load (same root cause)](#custom-agents-also-affected)
- [Voice mode not functional](#voice-mode-not-functional)
- [Hooks not firing (platform detection issue)](#hooks-not-firing-platform-detection-issue)
- [/tmp data lost](#tmp-data-lost)
- [Play Store Termux doesn't work](#play-store-termux-doesnt-work)
- [PDF reading fails ("pdftoppm is not installed")](#pdf-reading-fails-pdftoppm-is-not-installed)
- [`claude doctor` crashes](#claude-doctor-crashes)
- [Path C — AVF (Experimental)](#path-c--avf-experimental)
- [Upstream Issues](#upstream-issues)
- [ADB Wireless Debugging](#adb-wireless-debugging)

---

### Claude Code hangs on startup

**You see:** No output at all. The terminal sits there. No prompt, no error, no crash. `Ctrl+C` is your only way out.

```
$ claude
█
```

There is no error message. You will see a blinking cursor and nothing else, indefinitely.

**Fix:**

```bash
export TMPDIR=$PREFIX/tmp
```

Add it to `~/.bashrc` so it persists:

```bash
echo 'export TMPDIR=$PREFIX/tmp' >> ~/.bashrc
source ~/.bashrc
```

**Cause:** `TMPDIR` is not set. Claude Code and Node.js need a writable temporary directory. Termux does not set one by default, so npm's internal operations and Claude Code's IPC sockets have nowhere to go.

---

### Unsupported architecture: armhf

**You see:**

```
Unsupported architecture: armhf. Only amd64, arm64 are supported.
```

**Fix:** None. Claude Code requires a 64-bit (arm64/aarch64) operating system. Your device is running a 32-bit OS.

Check your architecture:

```bash
uname -m
```

If the output is `armv7l` or `armv8l`, your device cannot run Claude Code. This is a hard requirement with no workaround.

**Why this happens:** Some budget Android phones (Samsung Galaxy A13 5G, A02S, M13 5G, and others) ship with a 32-bit Android OS on 64-bit hardware. The phone's marketing materials may say "64-bit processor" but the OS runs in 32-bit mode. Claude Code checks `process.arch` at startup and rejects anything other than `arm64` or `x64`.

**Affected devices include:** Samsung Galaxy A13, A02S, M13 5G, A10, A6, and similar budget models from 2018-2023. Any phone where `uname -m` returns `armv7l` is affected regardless of the CPU's theoretical capability.

---

### Claude Code won't start, no error

**You see:** The command returns immediately to your shell prompt. No output, no error, no crash log.

```
$ claude
$
```

There is no error message. You will see the command exit silently and return to your prompt.

**Fix:** Launch Claude Code through `proot` with a bind mount:

```bash
pkg install proot -y
proot -b $PREFIX/tmp:/tmp claude
```

Create an alias so you don't have to type it every time:

```bash
echo "alias claude-android='proot -b \$PREFIX/tmp:/tmp claude'" >> ~/.bashrc
source ~/.bashrc
```

**Alternative fix (no proot):** Set `CLAUDE_CODE_TMPDIR` to redirect Claude Code's temp files:

```bash
export CLAUDE_CODE_TMPDIR=$PREFIX/tmp/claude
mkdir -p $PREFIX/tmp/claude
claude
```

This avoids proot entirely but only redirects Claude's own temp files — other tools that expect `/tmp` may still fail. The proot approach (shown above) is more comprehensive.

**Cause:** `/tmp` is not writable. Claude Code hardcodes `/tmp` for socket files, IPC, and ephemeral state. On Android, `/tmp` either doesn't exist or isn't writable from Termux's sandbox.

> **Note:** The proot bind mount resolves Claude Code operation including subagent task directories. Verified working with subagents on Android 16 (proot 5.1.107-70). Reports of EACCES on subagent tasks in issue [#15637](https://github.com/anthropics/claude-code/issues/15637) describe the experience *without* proot — the bind mount fixes it.

---

### OAuth / authentication fails on first launch

**You see:** The authentication flow fails, hangs, or the browser never opens. You may see:

```
Error: Failed to open browser
```

Or the auth URL prints to the terminal but nothing happens when you visit it, or the redirect back to `localhost` fails with a connection refused error.

**Fix:**

1. Install `termux-open-url` to enable browser integration:
   ```bash
   pkg install termux-tools -y
   ```
   Then retry `claude` — it should open your system browser for OAuth.

2. If the browser opens but the redirect fails, copy the auth URL manually from the terminal into your browser.

3. If all else fails, try authenticating with a direct API key:
   ```bash
   export ANTHROPIC_API_KEY="your-key-here"
   ```

**Cause:** Termux has no system browser integration by default. The OAuth redirect URL may not reach Termux because `localhost` inside Termux and `localhost` from the Android browser are not always the same network context.

---

### proot-distro issues

**You see:** Inside a `proot-distro` guest (Ubuntu, Debian, etc.), Claude Code produces no output or hangs.

```
$ proot-distro login ubuntu
root@localhost:~# claude
█
```

**Current status:** proot-distro **works** on Android 16 / kernel 6.12 with current proot versions (5.1.107-66+). A TCGETS2 ioctl bug that previously broke stdout in guest distros was fixed in October 2025. If you are seeing this issue, update proot first:

```bash
pkg upgrade proot proot-distro -y
```

**If it still hangs after updating proot:**

1. Check your proot version — must be 5.1.107-66 or later:
   ```bash
   dpkg -s proot | grep Version
   ```

2. Test with a simple command instead of interactive login:
   ```bash
   proot-distro login ubuntu -- sh -c 'echo hello'
   ```

3. If the simple command works but interactive login hangs, the issue may be terminal initialization. Try:
   ```bash
   proot-distro login ubuntu -- bash --norc --noprofile
   ```

**The warning `can't sanitize binding "/proc/self/fd/1"`** appears during proot-distro login and is harmless. stdout works correctly despite this message.

**Note:** proot-distro is a valid alternative to the native Termux approach. See [INSTALL.md — Path B](install.md#path-b-proot-distro-ubuntu) for the full setup guide. However, for Claude Code alone, the native Termux approach (Path A) is lighter and faster.

---

### Node.js v24 hangs

**You see:** Claude Code hangs on startup with Node.js v24. The process appears to start but never becomes interactive.

```
$ node -v
v24.x.x
$ claude
█
```

There is no error message. You will see the same hanging behavior as the TMPDIR issue, but `TMPDIR` is already set and proot is in use.

**Fix:** The v24 hang is specific to v24. v25 resolves it.

1. Try setting `export CLAUDE_CODE_TMPDIR=$HOME/tmp` in your `~/.bashrc` before
   launching (create the directory first: `mkdir -p ~/tmp`).
2. Or use Path B (proot-distro Ubuntu), where this constraint does not apply.

If neither resolves it, fall back to Node v25+:

```bash
pkg upgrade nodejs -y
node -v  # should show v25.x.x or higher
```

If `pkg upgrade` doesn't move you to v25, check that your Termux package repositories are current. The F-Droid version of Termux ships v25+ in its default repo.

**Cause:** The hang is specific to v24, not Termux generally. Node.js v24+ inside proot-distro Ubuntu does not exhibit this behavior in testing. v25 resolves it.

---

### Process killed randomly

**You see:** Claude Code or its subprocesses die mid-session. No error, no crash — the process just disappears. Your terminal may show:

```
[Process completed (signal 9) - press Enter]
```

Or the Claude Code session simply vanishes and you're back at your shell prompt.

**Fix:**

1. Minimize background apps while using Claude Code.
2. Limit concurrent subagents and child processes.
3. Enable the developer option to disable the restriction:

   **Settings -> Developer Options -> Disable child process restrictions** (toggle on)

   If you don't see Developer Options, go to **Settings -> About phone** and tap **Build number** seven times.

**Cause:** Android's phantom process killer. Android limits background processes to approximately 32 across all apps. When Termux spawns multiple Node.js processes (Claude Code, subagents, language servers), the OS silently kills excess processes.

**Session persistence with tmux:** Install tmux (`pkg install tmux`) and run Claude Code inside a tmux session (`tmux new -s claude`). If Android kills the Termux app, your session survives — reopen Termux and run `tmux attach -t claude` to resume.

---

### EMFILE errors

**You see:**

```
Error: EMFILE: too many open files, open '/data/data/com.termux/files/home/...'
```

or

```
Error: EMFILE, too many open files
```

**Fix:**

- Check your limit: `ulimit -n` (varies by device — measured 32,768 on Android 16 / kernel 6.12, may be lower on older devices)
- Avoid spawning unnecessary background processes.
- Close unused terminal sessions.
- If running multiple tools simultaneously, reduce parallelism.
- Restart Claude Code to release leaked file descriptors.

**Cause:** EMFILE means the process ran out of file descriptors. The limit varies by device and Android version. If you hit this, reduce concurrent operations or check if leaked FDs are the real issue (`ls /proc/$$/fd | wc -l`).

---

### npm install fails silently

**You see:** `npm install -g @anthropic-ai/claude-code` appears to complete but Claude Code isn't installed. Or the install produces no output and no binary:

```
$ npm install -g @anthropic-ai/claude-code
$
$ claude
bash: claude: command not found
```

There is no error message. You will see npm exit without complaint, but the package is not actually installed.

**Fix:**

```bash
export TMPDIR=$PREFIX/tmp
npm install -g @anthropic-ai/claude-code
```

Always set `TMPDIR` before any npm operation in Termux. Add it to `~/.bashrc` to make it permanent.

**Cause:** `TMPDIR` is not set. Without a writable temporary directory, npm cannot stage files or compile native addons. It fails silently rather than reporting an error.

---

### Grep/Glob/slash commands fail with ENOENT

**You see:**

```
spawn /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-android/rg ENOENT
```

Search tools (Grep, Glob) and slash commands that depend on them crash immediately. Claude Code may fall back to slower methods or simply fail the operation.

**Fix:** Install system ripgrep and symlink it into Claude Code's vendor directory:

```bash
pkg install ripgrep -y
VENDOR_DIR="$(dirname "$(command -v claude)")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
mkdir -p "$VENDOR_DIR/arm64-android"
ln -sf "$(command -v rg)" "$VENDOR_DIR/arm64-android/rg"
```

**Important:** This symlink breaks on Claude Code updates. Re-run the `mkdir` and `ln` commands after every `npm update -g @anthropic-ai/claude-code`.

**Cause:** Claude Code bundles platform-specific ripgrep binaries but does not include an `arm64-android` build. The binary path it expects simply doesn't exist.

### Custom agents also affected

If custom agents defined in `.claude/agents/` fail to load, it is the same root cause -- Claude Code's file search cannot find the agent definition files on `arm64-android`. The symlink fix above resolves agent loading as well.

**Permanent fix:** Instead of (or in addition to) the symlink, set this environment variable in your `~/.bashrc`:

```bash
export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1
echo 'export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1' >> ~/.bashrc
```

This tells Claude Code to use the system-installed ripgrep and file search tools instead of its bundled binaries. It fixes Grep, Glob, slash commands, and custom agent loading in one setting. The symlink approach still works but must be re-applied after every Claude Code update; this environment variable persists.

---

### Voice mode not functional

**You see:**

```
Voice mode requires SoX for audio recording. Install SoX manually:
```

The `/voice` command refuses to start.

**Fix:**

```bash
pkg install sox termux-api -y
```

Then grant microphone permission to Termux when Android prompts you (or manually via **Settings -> Apps -> Termux -> Permissions -> Microphone**).

**Note:** Voice mode functionality may still be limited on Android even after installing SoX and granting permissions. Audio routing on Android does not always cooperate with command-line tools.

**Cause:** SoX is available in Termux (`pkg install sox`) but voice mode also needs microphone access, which requires the Termux:API addon app and Android microphone permissions granted to Termux.

**Android 16 microphone input:** [PR #29074](https://github.com/termux/termux-packages/pull/29074) has been submitted to termux-packages to add an AAudio-based PulseAudio source module for Android 16. The current `module-sles-source` is broken on Android 16. If merged, this will enable microphone input for voice mode and other audio recording tools. Voice output via `termux-tts-speak` is unaffected and works without this fix.

---

### Hooks not firing (platform detection issue)

**You see:** Hooks configured in `.claude/settings.json` never trigger. There is no error message. You will see hooks simply not executing — no output from your hook scripts, no side effects.

SessionStart/SessionStop hooks may work, but PreToolUse/PostToolUse hooks do not fire at all.

You can verify the platform detection issue:

```
$ node -e "console.log(process.platform)"
android
```

If this prints `android` instead of `linux`, you are affected.

**Fix:** There is no complete fix — this is an upstream bug. Partial workarounds:

1. **proot approach** (may help): Running through `proot -b $PREFIX/tmp:/tmp claude` causes some system calls to report `linux` instead of `android`. Results vary by Claude Code version.

2. **cli.js patching** (fragile): Locate Claude Code's main script and patch platform checks. This breaks on every update.

3. **Track the upstream issue:** See [GitHub issue #16615](https://github.com/anthropics/claude-code/issues/16615) for the latest status.

**Cause:** Node.js reports `process.platform === "android"` on Termux, but Claude Code only checks for `darwin`, `win32`, and `linux`. Some code paths reject the `android` platform entirely, silently skipping hook execution.

---

### /tmp data lost

**You see:** Files you wrote to `/tmp` are gone. In-progress work that relied on `/tmp` state is lost.

There is no error message. You will see files simply missing from `/tmp` after a proot crash or session end.

**Fix:** Never store important state in `/tmp`. Treat it as disposable. Write anything you need to keep into your project directory or another persistent path under `$HOME`.

**Cause:** The proot bind mount is not a real filesystem mount — it's syscall interception. If proot crashes or the session ends, the mapping disappears. `/tmp` under proot is ephemeral.

---

### Play Store Termux doesn't work

**You see:** Packages fail to install, repositories are missing, or the app behaves unexpectedly:

```
E: Unable to locate package nodejs
```

or

```
E: The repository 'https://termux.org/packages stable Release' does not have a Release file.
```

**Fix:** Uninstall the Play Store version and install Termux from one of these sources:

- [F-Droid](https://f-droid.org/en/packages/com.termux/)
- [Termux GitHub releases](https://github.com/termux/termux-app/releases) (direct APK)

After installing, run:

```bash
pkg update && pkg upgrade -y
```

**Cause:** The Play Store version of Termux has not been updated since 2020. It does not support current package repositories, and its bundled tools are too old to run Claude Code.

---

### PDF reading fails ("pdftoppm is not installed")

**You see:**

```
pdftoppm is not installed
```

The `Read` tool returns this error when you try to read a `.pdf` file, even after running `pkg install poppler`.

**Fix:** Create a `which` shim -- Termux doesn't ship a `which` binary, and Claude Code's PDF reader uses `which pdftoppm` to detect the tool:

```bash
pkg install poppler
cat > $PREFIX/bin/which << 'SCRIPT'
#!/usr/bin/env bash
for arg in "$@"; do
  command -v "$arg"
done
SCRIPT
chmod +x $PREFIX/bin/which
```

After this, `Read` on PDF files works correctly.

Alternatively, `pdftotext` (included with poppler) works without the shim if you only need text extraction: `pdftotext file.pdf -`

**Cause:** Termux uses `command -v` rather than `which` for command detection, but Claude Code's PDF reader calls `which pdftoppm` directly. Without a `which` binary on PATH, the check fails and the reader refuses to proceed, even if `pdftoppm` is installed.

---

### `claude doctor` crashes

**You see:**

```
Raw mode is not supported on the current process.stdin
```

`claude doctor` outputs this error and exits without completing any checks.

**Fix (not yet confirmed on all devices):** Run `claude doctor` in a direct interactive Termux session -- not backgrounded, not piped, not launched from within Claude Code itself:

```bash
# Open a fresh Termux terminal session and run:
claude doctor
```

If you are running it from inside a Claude Code session via the Bash tool, that won't work -- the Bash tool does not provide a raw-mode terminal.

**Cause:** The `claude doctor` command uses the Ink library to render its output. Ink requires raw mode stdin. Termux provides raw mode in interactive sessions but not in piped or backgrounded contexts.

**Status:** Cosmetic -- `doctor` is a diagnostic tool, not required for normal Claude Code operation. All the checks it runs can also be done manually (see the `/doctor` skill).

---

## Upstream Issues

Known issues filed against the Claude Code repository that affect Android/Termux users:

| Issue | Description | Status | Workaround |
|-------|-------------|--------|------------|
| [#15637](https://github.com/anthropics/claude-code/issues/15637) | Hardcoded `/tmp/claude` paths | Open | proot bind mount |
| [#16615](https://github.com/anthropics/claude-code/issues/16615) | Platform detection — `android` not recognized | Closed (not planned) | cli.js patching |
| [#9435](https://github.com/anthropics/claude-code/issues/9435) | Missing arm64-android ripgrep binary | Closed | System ripgrep + symlink |
| [PR #31701](https://github.com/anthropics/claude-code/pull/31701) | Fix: respect `$TMPDIR` instead of hardcoding `/tmp` | Closed (not merged) | -- |

---

## ADB Wireless Debugging

### "error: protocol fault (couldn't read status message): Success" during pairing

This is a known bug in ADB 35.x (Google Issue Tracker #329947334). The error message
is misleading — it can appear even when the pairing partially or fully succeeds.

**Workaround:**
1. If you see this error, try running `adb connect 127.0.0.1:<connection-port>`
   immediately after, using the port shown in the wireless debugging settings screen
   (not the pairing port — the main connection port).
2. If that fails, close and reopen the "Pair device with pairing code" dialog in
   Developer Options to get a new code, then retry `adb pair`.
3. The second pairing attempt typically succeeds. If it does not, restart the ADB
   server (`adb kill-server && adb start-server`) and try once more.

Once successfully connected, run `adb devices` to confirm — the device should appear
as `127.0.0.1:<port> device`.

---

### Does the ADB connection survive screen lock or reboot?

**Screen lock:** The `adb connect` session drops on screen lock. You must run
`adb connect 127.0.0.1:<port>` again after unlocking.

**App switching / Termux backgrounding:** The connection drops when you switch apps
or background Termux. Reconnect with `adb connect` before issuing further ADB commands.

**Device reboot:** The connection does not survive reboot. After reboot, you must
run `adb connect 127.0.0.1:<port>` again. The connection port changes on each
wireless debugging restart — it is assigned dynamically by Android. Check the
current port in Developer Options → Wireless debugging → the port shown on the main
wireless debugging screen (not the pairing dialog).

**Re-pairing after reboot:** You typically do not need to re-pair (run `adb pair`)
after a reboot if you have already paired once. The pairing is remembered. Only
re-pairing is required if you revoke trusted devices or re-enable wireless debugging
from scratch.

**Automating reconnect:** You can add `adb connect 127.0.0.1:<port>` to your
Termux startup script, but be aware the port changes on each wireless debugging
restart. A more robust approach is to check the current port from Developer Options
and reconnect manually when needed. Boot automation for dynamic ports is not yet
solved cleanly — contributions welcome.

---

## Path C -- AVF (Experimental)

### Android Virtualization Framework (AVF) -- Experimental, Tested on Pixel

Android 16 includes a built-in Linux VM via the Android Virtualization Framework (AVF). Claude Code has been installed and used for real work inside an AVF VM on a Pixel 10 Pro (tested 2026-04-01). It is now documented as **Path C -- experimental**.

See **[AVF-GUIDE.md](avf-guide.md)** for the full setup checklist, VM configuration, ADB hardware bridge setup, security defaults, and comparison with Path A and Path B.

**What works:**
- Claude Code installs via the official Anthropic installer and completed real tasks during our testing
- `process.platform === "linux"` -- no platform detection issues
- Native `/tmp` -- no bind mounts or TMPDIR workarounds
- Standard `apt` package management, including systemd updates
- RAM allocation is configurable via the `memory_mib` field in `/mnt/internal/linux/vm_config.json` (default 4 GB, we changed this to 8 GB on our test device)
- ADB wireless debugging from inside the VM provides access to 42 phone sensors, GPS, camera, screenshots, screen recording, input injection, battery state, and WiFi info
- Audio playback and recording (PulseAudio + VirtIO SoundCard)
- Headless GUI rendering (Firefox screenshots, automated browser tasks)

**What doesn't work well (yet):**
- **VM killed when screen turns off** -- the most-reported AVF issue. ADB whitelist commands improved stability in our testing (the VM survived screen-off and always-on-display-off) but this is a semi-fix -- the Terminal app Activity can still get recreated, disrupting the session even though the VM itself may survive. Google acknowledged the issue at LPC 2025.
- **SysV IPC disabled in kernel** -- fio and some Python multiprocessing features do not work (CONFIG_SYSVIPC not set). Hard wall.
- **nftables non-functional** -- use iptables-legacy instead
- **`apt upgrade` can hang** -- whiptail TUI dialogs block non-interactive sessions. Use `DEBIAN_FRONTEND=noninteractive` or kill the blocking process.
- **"VM damaged" on unclean shutdown** -- requires full reinstall of the Debian image
- **Samsung/Snapdragon not supported** -- Qualcomm only supports "protected" VMs; Knox RKP conflicts with AVF. Hardware/firmware limitation.
- **No Termux API access** -- camera, TTS, clipboard, GPS, SMS, sensors are not available inside the VM natively (partial access via ADB bridge)
- **No kernel module loading** -- monolithic kernel, /lib/modules/ is empty
- **Copy-paste unreliable** -- multi-line commands break when pasted into the Terminal app

**Security note:** The VM ships with convenience-oriented defaults (known default password, SSH password auth enabled, no firewall, passwordless sudo). See the AVF guide's security section for details and hardening suggestions.

**Networking fix:** Cellular data requires enabling "Unrestricted mobile data usage" in the Terminal app's settings, then restarting the device. WiFi works without this step. (Google Issue Tracker #402523629)

**Using AVF?** [Open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) with your findings -- we're tracking stability reports across devices.
