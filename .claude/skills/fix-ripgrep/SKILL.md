---
name: fix-ripgrep
description: Fix Claude Code's broken Grep/Glob tools on Android by installing system ripgrep and symlinking it into the vendor directory.
user-invocable: true
disable-model-invocation: true
argument-hint: (no arguments needed)
allowed-tools: Bash, Read, Grep
---

# Fix Ripgrep on Android/Termux

Claude Code bundles platform-specific ripgrep binaries but does NOT include an `arm64-android` variant. This causes the Grep, Glob, and slash command tools to fail with:

```
spawn .../vendor/ripgrep/arm64-android/rg ENOENT
```

## What this skill does

1. Checks if the `arm64-android/rg` binary already exists and works
2. If not: installs system ripgrep via `pkg install ripgrep`
3. Creates the `arm64-android` directory in Claude Code's vendor path
4. Symlinks system `rg` into it
5. Verifies the fix by running a test grep

## Instructions

Run these steps in order. Stop and report if any step fails.

**Step 1, Detect the problem:**
```bash
VENDOR_DIR="$(dirname "$(command -v claude)")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
echo "Vendor dir: $VENDOR_DIR"
ls "$VENDOR_DIR/arm64-android/rg" 2>/dev/null && echo "ALREADY FIXED" || echo "NEEDS FIX"
```

**Step 2, Install system ripgrep (if not present):**
```bash
command -v rg >/dev/null 2>&1 && echo "ripgrep already installed" || pkg install ripgrep -y
```

**Step 3, Create symlink:**
```bash
VENDOR_DIR="$(dirname "$(command -v claude)")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
mkdir -p "$VENDOR_DIR/arm64-android"
ln -sf "$(command -v rg)" "$VENDOR_DIR/arm64-android/rg"
echo "Symlink created: $(ls -la "$VENDOR_DIR/arm64-android/rg")"
```

**Step 4, Verify:** Use the Grep tool (not bash grep) to search for any string in the current directory. If it returns results without ENOENT, the fix worked.

## Important notes

- This symlink breaks when Claude Code updates. Re-run `/fix-ripgrep` after any Claude Code upgrade.
- This is a workaround. The upstream fix is tracked at [anthropics/claude-code#9435](https://github.com/anthropics/claude-code/issues/9435).

Report: what was the state before, what was done, does Grep work now.
