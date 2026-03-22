---
name: termux-safe
description: Auto-loaded Android/Termux constraints. Prevents Claude from suggesting commands that fail silently on Android.
user-invocable: false
---

# Android / Termux Environment Constraints

> **Scope:** These constraints apply to native Termux only. Inside a proot-distro guest (Path B), standard Linux rules apply — `apt` works normally, `/tmp` is writable, paths are standard.

You are running inside Termux on Android (aarch64). These constraints produce **silent failures, not errors.** Every suggestion must account for them.

## Hard Rules — Never Suggest These

- **No `sudo`.** Root does not exist. No `su`, no `doas`, no privilege escalation of any kind.
- **No `systemctl` or `systemd`.** Android does not use systemd. No `journalctl`, no `service`, no unit files.
- **No standard Linux paths.** `/usr/bin`, `/etc`, `/var` do not exist or are not writable. Termux paths:
  - Home: `/data/data/com.termux/files/home`
  - Prefix: `/data/data/com.termux/files/usr`
  - Binaries: `$PREFIX/bin`
  - Config: `$PREFIX/etc`
- **No ports below 1024.** No root = no binding to 80, 443, etc. Use 1024+.
- **No `apt` or `apt-get`.** Termux uses `pkg`. Example: `pkg install nodejs -y`.
- **No Docker, no containers.** The kernel does not support them without root.

## Silent Failure Modes

- **`/tmp` is not writable** without proot. Claude Code requires: `proot -b $PREFIX/tmp:/tmp claude`
- **`TMPDIR` must be set** before npm operations: `export TMPDIR=$PREFIX/tmp`
- **Node.js v24 had a startup hang** on ARM64 under native Termux (resolved in v25). Require v25+. If users are stuck on v24, suggest CLAUDE_CODE_TMPDIR workaround or Path B.
- **File descriptor limits vary by device.** Check with `ulimit -n`. Avoid spawning many concurrent processes.
- **Android phantom process killer** limits background processes to ~32 across all apps. If "Disable child process restrictions" is enabled in Developer Options, this limit is lifted and up to 6 concurrent subagents are safe. Otherwise limit to 2-3.
- **proot crash = /tmp mount gone.** Never store persistent state in `/tmp`.
- **`process.platform` returns `"android"`**, not `"linux"`. Some tools check for `linux` specifically and fail.

## Package Installation

Use `pkg`, not `apt`:
```bash
pkg install <package> -y
pkg upgrade
pkg search <query>
```

## When Unsure

If you're about to suggest a command that assumes standard Linux, stop and verify it works on Termux first. When in doubt, prefix with `command -v <tool> >/dev/null 2>&1` to check availability.
