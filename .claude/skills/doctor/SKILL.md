---
name: doctor
description: Diagnose your Android/Termux environment (not the built-in `claude doctor`). Checks proot, TMPDIR, Node version, ripgrep, Termux:API, phantom process killer, and fd limits.
user-invocable: true
argument-hint: (no arguments needed)
allowed-tools: Bash, Grep
---

# Claude Code Android -- Environment Diagnostic

> **Not the same as `claude doctor`.** The built-in `claude doctor` checks Claude Code's own health. This skill checks the Android/Termux environment: proot, TMPDIR, Node version, ripgrep, Termux:API, process limits, and storage.

Run every check below. Report results as a table: component, status (PASS/FAIL/WARN), detail.

## Checks to Run

**1. Node.js version:**
```bash
node -v
```
PASS if v25+. WARN if v24 (startup hang reported on ARM64, resolved in v25). FAIL if below v24 or not installed.

**2. Claude Code installed:**
```bash
claude --version 2>/dev/null || echo "NOT FOUND"
```
PASS if version returned. FAIL if not found.

**3. proot installed:**
```bash
proot --help 2>&1 | head -1
```
PASS if proot responds. FAIL if not installed.

**4. TMPDIR set:**
```bash
echo "TMPDIR=$TMPDIR"
```
PASS if set to a writable path (typically `$PREFIX/tmp`). FAIL if empty.

**5. TMPDIR in .bashrc (persistence):**
```bash
grep -q 'TMPDIR' ~/.bashrc 2>/dev/null && echo "PERSISTED" || echo "NOT PERSISTED"
```
PASS if persisted. WARN if not (will be lost on terminal restart).

**6. /tmp writable via proot:**
```bash
proot -b $PREFIX/tmp:/tmp ls /tmp >/dev/null 2>&1 && echo "WRITABLE" || echo "NOT WRITABLE"
```
PASS if writable. FAIL if not.

**7. ripgrep (Grep tool):**
```bash
VENDOR_DIR="$(dirname "$(command -v claude)")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
ls "$VENDOR_DIR/arm64-android/rg" 2>/dev/null && echo "PRESENT" || echo "MISSING"
```
PASS if arm64-android/rg exists. FAIL if missing. Suggest: run `/fix-ripgrep`.

**8. Termux source:**
```bash
pkg show termux-tools 2>/dev/null | head -5 || echo "UNKNOWN"
```
WARN if Play Store version detected (outdated, will fail).

**9. File descriptor limit:**
```bash
ulimit -n
```
PASS if >= 1024. WARN with note about heavy I/O limitations.

**10. Background process count:**
```bash
ps aux 2>/dev/null | wc -l || ps | wc -l
```
WARN if above 25 (phantom process killer risk at ~32).

**11. Storage:**
```bash
df -h /data/data/com.termux/files/home | tail -1
```
WARN if less than 500MB free.

**12. Alias configured:**
```bash
grep -q 'claude-android\|proot.*claude' ~/.bashrc 2>/dev/null && echo "CONFIGURED" || echo "NOT SET"
```
PASS if alias exists. WARN if not (user has to type proot command every time).

**13. Termux:API installed:**
```bash
command -v termux-battery-status >/dev/null 2>&1 && echo "INSTALLED" || echo "MISSING"
```
PASS if installed. WARN if missing (Termux API features like battery, camera, TTS, clipboard will not work).

## Output Format

Present results as:

```
Claude Code Android — Doctor Report

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | Node.js | PASS | v25.8.1 |
| 2 | Claude Code | PASS | v2.1.78 |
...
```

After the table, list any FAIL items with one-line fix commands. For ripgrep failures, suggest `/fix-ripgrep`.
