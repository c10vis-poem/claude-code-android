# Troubleshooting Claude Code on Android

This guide covers problems specific to running Claude Code on **aarch64/ARM64 Android 8+ with Termux**. Android 8 / 9 have OAuth caveats (see [FAQ](faq.md#claude-prints-a-url-but-my-browser-doesnt-open)). Each entry starts with the error you see, then the fix, then the explanation.

If you haven't installed yet, see [install.md](install.md) first.

---

## Table of Contents

- [Claude crashes immediately on launch](#claude-crashes-immediately-on-launch)
- [Claude hangs on "Checking connectivity" / ETIMEOUT / 'API error' on every message](#claude-hangs-on-checking-connectivity--etimeout--api-error-on-every-message)
- [Unsupported architecture: armhf](#unsupported-architecture-armhf)
- [Claude Code won't start, no error](#claude-code-wont-start-no-error-v2x-install)
- [Claude Code exits: "native binary not installed"](#claude-code-exits-native-binary-not-installed-historical--v2x-context)
- [Claude can't find a tool (jq / git / python / ...)](#claude-cant-find-a-tool-jq--git--python--)
- [OAuth / authentication fails on first launch](#oauth--authentication-fails-on-first-launch)
- [proot-distro issues](#proot-distro-issues)
- [Node.js v24 hangs](#nodejs-v24-hangs)
- [Process killed randomly](#process-killed-randomly)
- [EMFILE errors](#emfile-errors)
- [npm install fails silently](#npm-install-fails-silently-your-own-packages-not-claude-code)
- [Grep/Glob/slash commands fail with ENOENT](#grepglobslash-commands-fail-with-enoent-v2x-install)
- [Custom agents fail to load (same root cause)](#custom-agents-v2x)
- [`#!/usr/bin/env` scripts fail with "bad interpreter"](#usrbinenv-scripts-fail-with-bad-interpreter-v291)
- [Voice mode not functional](#voice-mode-not-functional)
- [Hooks on Termux native](#hooks-on-termux-native)
- [Termux from Google Play has issues](#termux-from-google-play-has-issues)
- [PDF reading fails ("pdftoppm is not installed")](#pdf-reading-fails-pdftoppm-is-not-installed)
- [`claude doctor` crashes](#claude-doctor-crashes)
- [Path C: AVF (Experimental)](#path-c-avf-experimental)
- [Upstream Issues](#upstream-issues)
- [ADB Wireless Debugging](#adb-wireless-debugging)

---

### Claude crashes immediately on launch

**You see:** one of these the instant you run `claude`, often right after it had been working fine:

```
Bad system call
```

or

```
oh no: Bun has crashed. This indicates a bug in Bun, not your code.
```

or a `Segmentation fault` message that links to `bun.report`. Tellingly, `claude --version` still prints a version, but `claude` on its own dies straight away.

**What happened:** Claude Code auto-updated itself to a release that does not run on Android. Claude Code is a single native program, and a recent build of it asks Android for something Android does not allow, so it stops the moment it starts. This is a bug in that release, not in your phone, and not anything you did.

**Fix it:** re-run this repo's installer (below). However you first installed, on a phone that already has this setup it refreshes the launcher in place, without the large re-download, updating it to a version that checks each Claude Code update before running it and, on its own, falls back to the last one that worked. Your login and settings are kept.

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
bash install.sh
```

Then start Claude Code the normal way. The refreshed launcher checks the installed version and, if it crashes, rolls back to the last one that worked, with no further action from you.

If you are still on the older pinned install (Claude Code `2.1.112` with the auto-updater off), `install.sh` will point you to `migrate.sh` instead. Run that: it upgrades you to the current self-healing setup.

**If you then see `no working claude binary found`:** your phone has no good version saved to fall back to. Install the pinned version, an older Claude Code that does not have this problem:

```bash
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install-pinned.sh -o install-pinned.sh
bash install-pinned.sh
```

The pinned version is a safety net, not a one-way street: once a working Claude Code release is out, re-run `install.sh` to move back to the current, self-healing setup.

Running Claude Code inside proot-distro Ubuntu (Path B) is another way around it; see the [install guide](install.md).

**Why it happens, briefly:** Android runs every app under a filter that permits only a fixed set of low-level system calls. A native program like Claude Code sometimes uses a newer system call the filter was not told to allow, and Android stops the program instead of letting the call through. `claude --version` survives because it quits before it reaches that point; a real launch does not. The launcher in v2.9.2 and later tests each version this way and rolls back when one fails. One instance, on newer phones, is in the Bun runtime Claude Code is built on, tracked upstream at oven-sh/bun#32489.

---

### Claude hangs on "Checking connectivity" / ETIMEOUT / 'API error' on every message

**You see:** Claude starts, then hangs on `Checking connectivity...` and fails with:

```
Unable to connect to Anthropic services
Failed to connect to api.anthropic.com: ETIMEOUT
```

even though `curl https://api.anthropic.com/` connects fine over both IPv4 and IPv6. It is often **intermittent** (fine one launch, hung the next) and is unrelated to your Claude Code version or to running as root. (On an already-logged-in session it may instead surface as an API error when you send a message.)

**Fix:** Update to the latest `install.sh` (or just re-run if using the curl + bash command). The launcher now points Claude Code's DNS resolver at a working nameserver automatically: it writes a tiny `setdns.js` next to the binary and loads it with `BUN_OPTIONS=--preload` on every launch (no binary patching, no extra permissions, no daemon). To confirm it's in place:

```bash
cat ~/.local/share/claude/setdns.js   # -> require("dns").setServers(["8.8.8.8", ...])
```

If you'd rather fix it by hand without re-running the installer, set it in the shell that launches claude:

```bash
echo 'try { require("dns").setServers(["8.8.8.8","8.8.4.4"]); } catch(e){}' > ~/setdns.js
export BUN_OPTIONS="--preload $HOME/setdns.js"
```

**Why it happens, briefly:** Claude Code is built with Bun, whose DNS resolver (c-ares) reads `/etc/resolv.conf` to find a nameserver. On Android `/etc` is a read-only link to `/system/etc` with no `resolv.conf`, so c-ares falls back to its built-in default `127.0.0.1:53`, where nothing is listening. The glibc resolver Termux ships *does* work (it reads `$PREFIX/glibc/etc/resolv.conf`), but Bun uses both, and under the burst of name lookups at startup the dead-loopback queries time out and starve the working path. `curl` is unaffected because it uses Android's own (bionic/netd) resolver. The preload calls `dns.setServers()` to hand c-ares a live nameserver before the first lookup, so it never hits the dead loopback.

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

### Claude Code won't start, no error (v2.x install)

**You see:** The command returns immediately to your shell prompt. No output, no error, no crash log.

```
$ claude
$
```

**Affected:** v2.x users on the pinned 2.1.112 npm install. The v2.9.0 install (current `install.sh`) does NOT exhibit this symptom: it runs the linux-arm64 native binary directly under glibc-runner (a Termux package providing a glibc-compatible dynamic linker for Linux binaries) rather than the npm-installed JS bundle.

**Cause (v2.x):** The in-process auto-updater replaced the pinned 2.1.112 install with a 2.1.113+ build that has no android-arm64 binary. The replaced binary loads but exits before producing output. The `chmod -R a-w` lock applied by the v2.x `install.sh` should prevent this; if the install dir is no longer read-only, the lock was undone.

**Recovery (v2.x):** Re-run a fresh `install.sh`. This now installs the v2.9.0 architecture, which sidesteps the issue entirely. Or, if you must stay on v2.x, manually reinstall 2.1.112:

```bash
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/ 2>/dev/null
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@2.1.112
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
```

If bare `claude` exits silently after that, confirm `ls -la $PREFIX/lib/node_modules/@anthropic-ai/claude-code` shows `dr-x------`.

---

### Claude Code exits: "native binary not installed" (historical / v2.x context)

**You see:**

```
$ claude
Error: claude native binary not installed.

Either postinstall did not run (--ignore-scripts, some pnpm configs)
or the platform-native optional dependency was not downloaded
(--omit=optional).
```

**Affected:** Users on a v2.x install whose pinned 2.1.112 was clobbered by the in-process auto-updater pulling a 2.1.113+ build (no android-arm64 binary). The v2.9.0 install does not exhibit this: it runs the linux-arm64 native binary directly via glibc-runner.

**Cause:** Upstream regression introduced in `@anthropic-ai/claude-code` 2.1.113. Versions 2.1.113 and later switched from a bundled `cli.js` JavaScript entry point to a platform-native binary wrapped by an optional-dependency dispatcher; android-arm64 is not in the dispatcher's PLATFORMS map. Tracked upstream at [anthropics/claude-code#50270](https://github.com/anthropics/claude-code/issues/50270).

**Recovery (recommended):** upgrade to v2.9.0:

```bash
# 1) Remove the v2.x install
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/ 2>/dev/null || true
rm -rf $PREFIX/lib/node_modules/@anthropic-ai/claude-code/ $PREFIX/bin/claude
rm -f $HOME/.claude/settings.json   # optional; will be rewritten

# 2) Run the v2.9.0 install.sh
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
bash install.sh
```

**Recovery (stay on v2.x):**

```bash
chmod -R u+w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/ 2>/dev/null
DISABLE_AUTOUPDATER=1 npm install -g @anthropic-ai/claude-code@2.1.112
chmod -R a-w $PREFIX/lib/node_modules/@anthropic-ai/claude-code/
echo 'export DISABLE_AUTOUPDATER=1' >> ~/.bashrc
```

The `chmod -R a-w` was load-bearing under v2.x: the in-process auto-updater re-fetched `latest` on a timer and silently overwrote the install dir. v2.9.0 sidesteps the entire mechanism (`autoUpdates: false` in settings.json + a wrapper at `$PREFIX/bin/claude`, where `$PREFIX` is Termux's package prefix directory, outside the npm tree).

**Path B (proot-distro Ubuntu) was never affected** by this regression. Inside the Ubuntu guest, `process.platform === 'linux'` matches the upstream `linux-arm64` native binary directly.

---

### Claude can't find a tool (jq / git / python / ...)

**You see:** Claude tries to run `jq`, `git`, `python`, `gh`, `openssh`, `tree`, etc. and the command fails with `command not found`. Tool calls fail repeatedly with the same kind of error.

**Cause:** This is a vanilla Claude Code in an environment it is not used to. `install.sh` installs the claude binary and the glibc-runner/patchelf-glibc support it needs (glibc-runner provides a glibc-compatible dynamic linker for Linux binaries; patchelf-glibc is a Termux-packaged patchelf utility for modifying ELF binary metadata so they resolve against it). It does not install nodejs or most developer tools. Beyond what Termux core ships (`rg`, `curl`, `unzip`, `tar`, `gzip`, `less`, `nano`), most tools Claude reaches for are not present.

**Fix:** Install the **[Recommended Common Packages](install.md#recommended-common-packages)** in install.md (one `pkg install` line). Also consider injecting them into your `CLAUDE.md` or an environment hook so Claude knows what's available. Without that, expect recurring tool failures and barriers.

---

### OAuth / authentication fails on first launch

**You see:** The OAuth (browser-based login) flow fails, hangs, or the browser never opens. You may see:

```
Error: Failed to open browser
```

Or the auth URL prints to the terminal but nothing happens when you visit it, or the redirect back to `localhost` fails with a connection refused error.

**Fix:**

1. Install `termux-open-url` to enable browser integration:
   ```bash
   pkg install termux-tools -y
   ```
   Then retry `claude`; it should open your system browser for OAuth.

2. If the browser opens but the redirect fails, copy the auth URL manually from the terminal into your browser.

3. If all else fails, try authenticating with a direct API key:
   ```bash
   export ANTHROPIC_API_KEY="your-key-here"
   ```

**Cause:** Termux has no system browser integration by default. The login redirect URL may not reach Termux because `localhost` inside Termux and `localhost` from the Android browser are not always the same network context.

**Android-version note:** Auto-open behavior varies by Android version. Verified 2026-05-16: Pixel 10 Pro (A17 Beta), Pixel 6 (A13), and Moto G7 Power (A10) auto-open Chrome when claude triggers OAuth from inside proot-Ubuntu. Galaxy S7 (A8) does NOT auto-open. If you're on Android 8 or 9, copy the URL from the terminal and paste it into your phone's browser manually. See [FAQ: Claude prints a URL but my browser doesn't open](faq.md#claude-prints-a-url-but-my-browser-doesnt-open).

---

### proot-distro issues

**You see:** Inside a `proot-distro` guest (Ubuntu, Debian, etc.), Claude Code produces no output or hangs.

```
$ proot-distro login ubuntu
root@localhost:~# claude
█
```

**Current status:** A TCGETS2 ioctl bug that previously broke stdout in guest distros with glibc 2.41+ was fixed in proot 5.1.107-66 (October 2025). On the devices I have tested (Android 13 and Android 17), proot-distro works with current proot versions (5.1.107-66+). If you are seeing this issue on a different Android version, update proot first:

```bash
pkg upgrade proot proot-distro -y
```

**If it still hangs after updating proot:**

1. Check your proot version. Must be 5.1.107-66 or later:
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

**Note:** proot-distro is a valid alternative to the native Termux approach. See [install.md, Path B](install.md#path-b-proot-distro-ubuntu) for the full setup guide. However, for Claude Code alone, the native Termux approach (Path A) is lighter and faster.

---

### Node.js v24 hangs

**You see:** Claude Code hangs on startup with Node.js v24. The process appears to start but never becomes interactive.

```
$ node -v
v24.x.x
$ claude
█
```

There is no error message. The process appears to start but never becomes interactive.

**Fix:** The v24 hang is specific to v24. Upgrade Node to v25 or later:

```bash
pkg upgrade nodejs -y
node -v  # should show v25.x.x or higher
```

If `pkg upgrade` doesn't move you to v25, check that your Termux package repositories are current. The F-Droid version of Termux ships v25+ in its default repo. As a fallback, use Path B (proot-distro Ubuntu), where this constraint does not apply.

**Cause:** The hang is specific to v24, not Termux generally. Node.js v24+ inside proot-distro Ubuntu does not exhibit this behavior in testing. v25 resolves it.

---

### Process killed randomly

**You see:** Claude Code or its subprocesses die mid-session. No error, no crash; the process just disappears. Your terminal may show:

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

**Session persistence with tmux:** Install tmux (`pkg install tmux`) and run Claude Code inside a tmux session (`tmux new -s claude`). If Android kills the Termux app, your session survives. Reopen Termux and run `tmux attach -t claude` to resume.

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

- Check your limit: `ulimit -n` (varies by device). Soft / hard limits measured on the four devices in `tests/results/`: Pixel 10 Pro Android 17 reported soft 32,768 / hard 524,288; Pixel 6 Android 13 reported 32,768 / 32,768; older devices may report lower values.
- Avoid spawning unnecessary background processes.
- Close unused terminal sessions.
- If running multiple tools simultaneously, reduce parallelism.
- Restart Claude Code to release leaked file descriptors.

**Cause:** EMFILE means the process ran out of file descriptors. The limit varies by device and Android version. If you hit this, reduce concurrent operations or check if leaked FDs are the real issue (`ls /proc/$$/fd | wc -l`).

---

### npm install fails silently (your own packages, not Claude Code)

**You see:** You run your own `npm install -g <some-package>` and npm appears to finish without complaint, but the package is not actually installed. This is for your own npm work; `install.sh` in this repo handles the Claude Code install correctly without any extra setup.

**Fix:** Run `npm install` with `bash install.sh`'s shell environment, or call npm from a shell where the install script's environment has already been applied. If you are installing packages outside Termux's default location, you may need to set `npm config set prefix` to a writable path you own.

**Cause:** npm needs a writable working directory at install time. Termux's default shell environment provides one when set up by this repo's `install.sh`. If you launch npm from a stripped environment (cron, a shell with `env -i`, a non-interactive session that did not source your shell profile), npm may fail to stage files and exit quietly. This is generic Termux/npm behaviour; it does not affect the Claude Code install path documented in this repo.

---

### Grep/Glob/slash commands fail with ENOENT (v2.x install)

**You see:**

```
spawn /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-android/rg ENOENT
```

Search tools (Grep, Glob) and slash commands that depend on them crash immediately. Claude Code may fall back to slower methods or simply fail the operation.

**Affected:** v2.x installs only. On v2.9.0, the linux-arm64 native binary ships `vendor/ripgrep/arm64-linux/rg` and reports `process.platform === 'linux'`, so it finds its bundled rg on the first try. No env var or symlink needed.

**Recovery (v2.x / pinned 2.1.112):** Install system ripgrep and symlink it onto the exact vendored path Claude Code looks for. This is what `scripts/fix-ripgrep.sh` does:

```bash
pkg install ripgrep -y
VEN="$PREFIX/lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-android"
mkdir -p "$VEN"
ln -sf "$(command -v rg)" "$VEN/rg"
```

Re-run after a Claude Code update; the symlink does not survive updates.

**Cause:** The v2.x / pinned 2.1.112 install uses the npm-distributed JS bundle whose vendored ripgrep set has no `arm64-android` build, so the search tool spawns a path that does not exist. On 2.1.112 the `CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1` env var does not redirect the search (verified on device: with the symlink removed, Grep fails with the same ENOENT whether the flag is set in `~/.bashrc`, exported in the shell, or set in `settings.json` env). The symlink onto the vendored path is the fix.

### Custom agents (v2.x)

If custom agents defined in `.claude/agents/` fail to load on v2.x, it is the same root cause: Claude Code's file search cannot find the agent definition files on `arm64-android`. The ripgrep symlink above resolves agent loading as well. v2.9.0 does not exhibit this issue.

---

### `#!/usr/bin/env` scripts fail with "bad interpreter" (v2.9.1+)

**You see:**

```
/usr/bin/env: bad interpreter: No such file or directory
```

A script that claude's Bash tool runs **directly** and whose first line is `#!/usr/bin/env bash` (or `python3`, `node`, and so on) exits 126. This shows up with some project scripts and `node` CLI shims.

**Affected:** v2.9.1 and later. The install no longer sets `env.LD_PRELOAD` in `~/.claude/settings.json`, because that preload broke claude's own bundled grep, rg, and ugrep. Android has no `/usr/bin/env`; Termux's `termux-exec` preload is what rewrites `/usr/bin/env` to Termux's own `env`, and claude's subprocesses no longer carry that preload. This is a deliberate trade-off in favour of search working.

**Work around it:** run the interpreter explicitly instead of executing the file:

```bash
bash ./script.sh      # instead of ./script.sh
python ./script.py    # instead of ./script.py
node ./tool.js        # instead of ./tool.js
```

Tools called by name (`grep`, `git`, `python`, `node`) and `#!/bin/sh` scripts are unaffected, and a normal Termux shell outside claude is unaffected.

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

**Cause:** SoX (a command-line audio processing tool) is available in Termux (`pkg install sox`) but voice mode also needs microphone access, which requires the Termux:API addon app and Android microphone permissions granted to Termux.

**Android 16 microphone input:** [PR #29074](https://github.com/termux/termux-packages/pull/29074) has been submitted to termux-packages to add an AAudio-based PulseAudio source module for Android 16. The current `module-sles-source` is broken on Android 16. If merged, this will enable microphone input for voice mode and other audio recording tools. Voice output via `termux-tts-speak` is unaffected and works without this fix.

---

### Hooks on Termux native

**Status (verified 2026-04-18):** Hooks fire correctly on Termux native (`process.platform === "android"`). Earlier versions of this doc reported they did not, citing closed-not-planned upstream issue [#16615](https://github.com/anthropics/claude-code/issues/16615). Current Claude Code releases handle the `android` platform correctly. SessionStart and PreToolUse hooks with command-type entries and matchers like `Write|Edit|Read|Glob|Grep|Bash` execute as expected.

You can verify the platform identifier (informational, not a blocker):

```
$ node -e "console.log(process.platform)"
android
```

If your hooks are not firing on Termux:

1. Confirm the hook command path resolves on Termux (`$HOME` and `$PREFIX` expand inside the JSON config; absolute paths also work)
2. Set `timeout` explicitly in the hook entry (some hooks fail silently without one)
3. Verify hook exit codes (PreToolUse: `2` = block, `0` = allow; non-zero non-2 = non-blocking error)
4. For PreToolUse/PostToolUse, confirm the matcher pattern (regex) actually matches the tool name
5. Check `~/.claude/logs/` if present

---

### Termux from Google Play has issues

**You see:** If you installed Termux from a source that turned out to be outdated or limited, packages may fail to install, repositories may be missing, or the app may behave unexpectedly:

```
E: Unable to locate package nodejs
```

or

```
E: The repository 'https://termux.org/packages stable Release' does not have a Release file.
```

**Fix:** Uninstall the current Termux and install from one of these sources:

- [F-Droid](https://f-droid.org/en/packages/com.termux/)
- [Termux GitHub releases](https://github.com/termux/termux-app/releases) (direct APK, an Android app package file)

After installing, run:

```bash
pkg update && pkg upgrade -y
```

**Cause:** The upstream Termux maintainers describe the Google Play build as an experimental branch with missing functionality and bugs (see [github.com/termux/termux-app](https://github.com/termux/termux-app)); they recommend F-Droid or their GitHub releases for most users. If you have package-source or version issues with the Google Play build, switching to F-Droid or GitHub releases is the upstream-recommended fix.

---

### PDF reading fails ("pdftoppm is not installed")

**You see:**

```
pdftoppm is not installed
```

The `Read` tool returns this error when you try to read a `.pdf` file, even after running `pkg install poppler`.

**Fix:** Create a `which` shim. Termux doesn't ship a `which` binary, and Claude Code's PDF reader uses `which pdftoppm` to detect the tool:

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

**Fix (not yet confirmed on all devices):** Run `claude doctor` in a direct interactive Termux session. Not backgrounded, not piped, not launched from within Claude Code itself:

```bash
# Open a fresh Termux terminal session and run:
claude doctor
```

If you are running it from inside a Claude Code session via the Bash tool, that won't work. The Bash tool does not provide a raw-mode terminal.

**Cause:** The `claude doctor` command uses the Ink library (a React-based terminal UI renderer) to render its output. Ink requires raw mode stdin. Termux provides raw mode in interactive sessions but not in piped or backgrounded contexts.

**Status:** Cosmetic. `claude doctor` is a diagnostic tool, not required for normal Claude Code operation. This repo ships an equivalent set of Termux/Android-specific checks as a bash script: [`scripts/check-termux-env.sh`](../scripts/check-termux-env.sh).

---

## Upstream Issues

Known issues filed against the Claude Code repository that affect Android/Termux users:

| Issue | Description | Status | Notes |
|-------|-------------|--------|-------|
| [#50270](https://github.com/anthropics/claude-code/issues/50270) | 2.1.113+ broken on Termux/Android: native binary requires glibc, no JS fallback | Open | v2.9.0 install in this repo runs the linux-arm64 native binary directly under Termux's glibc-runner; see [README](../README.md#path-a-native-termux) |
| [#16615](https://github.com/anthropics/claude-code/issues/16615) | Platform detection: `android` not recognized | Closed (not planned) | Historic. Path A v2.9.0 ships the linux-arm64 binary which reports `process.platform === 'linux'`, sidestepping the detection problem entirely |
| [#9435](https://github.com/anthropics/claude-code/issues/9435) | Missing arm64-android ripgrep binary | Closed | v2.x / pinned 2.1.112: symlink system rg onto `vendor/ripgrep/arm64-android/rg` (`scripts/fix-ripgrep.sh`); the env var does not redirect the search on 2.1.112. v2.9.0 install: not applicable. The linux-arm64 binary ships `vendor/ripgrep/arm64-linux/rg` and uses it |

---

## ADB Wireless Debugging

### "error: protocol fault (couldn't read status message): Success" during pairing

This is a known bug in ADB 35.x (Google Issue Tracker #329947334). The error message
is misleading; it can appear even when the pairing partially or fully succeeds.

**Workaround:**
1. If you see this error, try running `adb connect 127.0.0.1:<connection-port>`
   immediately after, using the port shown in the wireless debugging settings screen
   (not the pairing port; the main connection port).
2. If that fails, close and reopen the "Pair device with pairing code" dialog in
   Developer Options to get a new code, then retry `adb pair`.
3. The second pairing attempt typically succeeds. If it does not, restart the ADB
   server (`adb kill-server && adb start-server`) and try once more.

Once successfully connected, run `adb devices` to confirm; the device should appear
as `127.0.0.1:<port> device`.

---

### Does the ADB connection survive screen lock or reboot?

**Screen lock:** The `adb connect` session drops on screen lock. You must run
`adb connect 127.0.0.1:<port>` again after unlocking.

**App switching / Termux backgrounding:** The connection drops when you switch apps
or background Termux. Reconnect with `adb connect` before issuing further ADB commands.

**Device reboot:** The connection does not survive reboot. After reboot, you must
run `adb connect 127.0.0.1:<port>` again. The connection port changes on each
wireless debugging restart; it is assigned dynamically by Android. Check the
current port in Developer Options → Wireless debugging → the port shown on the main
wireless debugging screen (not the pairing dialog).

**Re-pairing after reboot:** You typically do not need to re-pair (run `adb pair`)
after a reboot if you have already paired once. The pairing is remembered. Only
re-pairing is required if you revoke trusted devices or re-enable wireless debugging
from scratch.

**Automating reconnect:** You can add `adb connect 127.0.0.1:<port>` to your
Termux startup script, but be aware the port changes on each wireless debugging
restart. A more reliable approach is to check the current port from Developer Options
and reconnect manually when needed. Boot automation for dynamic ports is not yet
solved cleanly. Contributions welcome.

---

## Path C: AVF (Experimental)

### Android Virtualization Framework (AVF): Experimental, Tested on Pixel

Android 16 introduced a built-in Linux VM via the Android Virtualization Framework (AVF), and Android 17 expanded the Terminal app's user-facing controls. Claude Code has been installed and used for real work inside an AVF VM on Pixel 6 and Pixel 10 Pro running Android 17 (verified 2026-05-26). Path C is **experimental**.

See **[avf-guide.md](avf-guide.md)** for the full setup checklist, the Settings UI walkthrough, ADB hardware bridge, security defaults, and comparison with Path A and Path B.

**What works:**
- Claude Code installs via the official Anthropic installer (`curl -fsSL https://claude.ai/install.sh | bash`) and completed real tasks during my testing
- `process.platform === "linux"` (no platform detection issues)
- Native `/tmp` inside the VM
- Standard `apt` package management, including systemd updates
- Memory size, Display resolution, and Keep awake are configurable in the Terminal app's Settings (gear icon) under Advanced
- ADB wireless debugging from inside the VM provides access to phone sensors, GPS, camera, screenshots, screen recording, input injection, battery state, and WiFi info
- Audio playback and recording (PulseAudio + VirtIO SoundCard)
- Headless GUI rendering (Firefox screenshots, automated browser tasks)

**What doesn't work well (yet):**
- **Screen-off and Activity recreation:** Android 17 mitigates screen-off VM kills with Settings > Advanced > Keep awake (timer up to 1 day, with a battery-life warning in the dialog). The Terminal Activity can still be recreated by some Android lifecycle events (configuration changes, accessibility services). Run long workloads under `tmux` or `nohup` to survive Activity recreation.
- **SysV IPC (inter-process communication) disabled in kernel:** fio and some Python multiprocessing features do not work (`CONFIG_SYSVIPC` not set). Hard wall.
- **nftables non-functional:** use iptables-legacy instead
- **`apt upgrade` can hang:** whiptail text-based UI (TUI) dialogs block non-interactive sessions. Use `DEBIAN_FRONTEND=noninteractive` or kill the blocking process.
- **"VM damaged" on unclean shutdown:** requires the Recovery > Reset to initial version flow and a re-download of the Debian image
- **Snapdragon phones not supported:** Qualcomm exposes only protected VMs at EL2. Samsung's One UI 8.5 added Linux Terminal on Exynos S26 / S26+ per Samsung's release notes; not lab-verified here.
- **No Termux API access:** camera, text-to-speech (TTS), clipboard, GPS, SMS, sensors are not available inside the VM natively (partial access via ADB bridge)
- **No kernel module loading:** monolithic kernel, `/lib/modules/` is empty
- **Copy-paste unreliable:** multi-line commands break when pasted into the Terminal app

**Security note:** The VM ships with convenience-oriented defaults (known default password for the `droid` user, passwordless sudo, no firewall). SSH is installed but not running by default. See the AVF guide's security section for details and hardening suggestions.

**Networking fix:** Cellular data requires enabling "Unrestricted mobile data usage" in the Terminal app's settings, then restarting the device. WiFi works without this step. (Google Issue Tracker #402523629)

**Using AVF?** [Open an issue](https://github.com/ferrumclaudepilgrim/claude-code-android/issues/new?template=device_report.md) with your findings. I'm tracking stability reports across devices.

---

*Last updated: 2026-05-29.*
