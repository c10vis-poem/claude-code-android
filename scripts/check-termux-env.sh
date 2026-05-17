#!/usr/bin/env bash
# check-termux-env.sh -- Diagnose your Android/Termux environment for
#                       Claude Code on Android.
#
# NOT the same as `claude doctor`. The built-in `claude doctor` checks
# Claude Code's own runtime health. This script checks the Termux side:
# Node version, proot, TMPDIR, Grep/Glob fix (CLAUDE_CODE_USE_NATIVE_FILE_SEARCH), Termux:API,
# phantom-process-killer headroom, fd limits, and storage.
#
# Use this when something is wrong and you want to know which Termux
# constraint is biting you. Use it after a fresh install to sanity-check
# the environment. Safe to run repeatedly; read-only except for one
# transient temp file under $TMPDIR.
#
# Usage:
#   bash scripts/check-termux-env.sh
#
# Exit codes:
#   0 = all FAIL=0 (any number of WARN allowed; WARN is advisory)
#   1 = one or more FAIL items (something is broken)

set -uo pipefail

FAILS=0
WARNS=0
PASSES=0

row() {
  local n="$1"
  local check="$2"
  local status="$3"
  local detail="$4"
  printf '| %2s | %-30s | %-4s | %s\n' "$n" "$check" "$status" "$detail"
  case "$status" in
    PASS) PASSES=$((PASSES+1)) ;;
    WARN) WARNS=$((WARNS+1)) ;;
    FAIL) FAILS=$((FAILS+1)) ;;
  esac
}

echo "Claude Code Android: Environment Diagnostic"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
echo ""
printf '| %2s | %-30s | %-4s | %s\n' '#' Check Status Detail
printf '| %2s-+-%-30s-+-%-4s-+-%s\n' '--' '------------------------------' '----' '------------------------------'

# --- 1. Node.js ---
NODE_VER="$(node -v 2>/dev/null || echo none)"
if [ "$NODE_VER" = none ]; then
  row 1 "Node.js installed" FAIL "node not on PATH (run: pkg install nodejs)"
else
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
  if [ "$NODE_MAJOR" -ge 25 ] 2>/dev/null; then
    row 1 "Node.js version" PASS "$NODE_VER"
  elif [ "$NODE_MAJOR" = 24 ]; then
    row 1 "Node.js version" WARN "v24 has startup hang on ARM64; upgrade to v25+"
  else
    row 1 "Node.js version" FAIL "$NODE_VER too old (require v25+)"
  fi
fi

# --- 2. Claude Code ---
CC_VER="$(claude --version 2>/dev/null | head -1 || echo NOT_FOUND)"
if [ "$CC_VER" = NOT_FOUND ]; then
  row 2 "Claude Code installed" FAIL "claude not on PATH (run install.sh)"
else
  row 2 "Claude Code version" PASS "$CC_VER"
fi

# --- 3. proot ---
if proot --help >/dev/null 2>&1; then
  PROOT_VER="$(proot --version 2>&1 | head -1)"
  row 3 "proot installed" PASS "$PROOT_VER"
else
  row 3 "proot installed" FAIL "proot not responding (run: pkg install proot)"
fi

# --- 4. TMPDIR set ---
if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && [ -w "$TMPDIR" ]; then
  row 4 "TMPDIR set + writable" PASS "$TMPDIR"
else
  row 4 "TMPDIR set + writable" FAIL "TMPDIR='${TMPDIR:-}' (require \$PREFIX/tmp)"
fi

# --- 5. TMPDIR persisted ---
if grep -q 'TMPDIR' "$HOME/.bashrc" 2>/dev/null; then
  row 5 "TMPDIR in ~/.bashrc" PASS "persisted"
else
  row 5 "TMPDIR in ~/.bashrc" WARN "not persisted (will be lost on new shell)"
fi

# --- 6. /tmp via proot ---
if proot -b "$PREFIX/tmp:/tmp" ls /tmp >/dev/null 2>&1; then
  row 6 "/tmp writable via proot" PASS "bind mount works"
else
  row 6 "/tmp writable via proot" FAIL "proot bind mount failed"
fi

# --- 7. ripgrep arm64-android binary ---
CC_BIN="$(command -v claude 2>/dev/null || true)"
RG_OK=no
if [ -n "$CC_BIN" ]; then
  VENDOR_DIR="$(dirname "$(readlink -f "$CC_BIN")")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
  if [ -e "$VENDOR_DIR/arm64-android/rg" ]; then
    RG_OK=yes
  fi
fi
if grep -q 'CLAUDE_CODE_USE_NATIVE_FILE_SEARCH' "$HOME/.bashrc" 2>/dev/null; then
  row 7 "Grep/Glob fix" PASS "CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1 in ~/.bashrc"
elif [ "$RG_OK" = yes ]; then
  row 7 "Grep/Glob fix" PASS "arm64-android/rg symlink present (legacy approach)"
else
  row 7 "Grep/Glob fix" FAIL "add 'export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1' to ~/.bashrc"
fi

# --- 8. Termux source ---
TERMUX_VER="$(pkg show termux-tools 2>/dev/null | awk -F: '/^Version:/ {print $2; exit}' | tr -d ' ' || true)"
if [ -n "$TERMUX_VER" ]; then
  row 8 "Termux source" PASS "termux-tools $TERMUX_VER"
else
  row 8 "Termux source" WARN "could not detect (Play Store version is outdated; use F-Droid)"
fi

# --- 9. fd limit ---
FD_LIMIT="$(ulimit -n)"
if [ "$FD_LIMIT" -ge 1024 ] 2>/dev/null; then
  row 9 "File descriptor limit" PASS "$FD_LIMIT"
else
  row 9 "File descriptor limit" WARN "$FD_LIMIT (may limit heavy I/O)"
fi

# --- 10. Background process count ---
# Phantom process killer trips around 32 processes for a single uid by default.
BG_COUNT="$(ps -o pid= 2>/dev/null | wc -l)"
if [ "$BG_COUNT" -lt 25 ] 2>/dev/null; then
  row 10 "Background process count" PASS "$BG_COUNT (headroom OK)"
else
  row 10 "Background process count" WARN "$BG_COUNT (close to phantom-killer threshold ~32)"
fi

# --- 11. Storage ---
FREE_MB="$(df -m "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "$FREE_MB" ] && [ "$FREE_MB" -ge 500 ] 2>/dev/null; then
  row 11 "Storage free" PASS "${FREE_MB}M available in \$HOME"
else
  row 11 "Storage free" WARN "${FREE_MB:-?}M (under 500MB is tight)"
fi

# --- 12. claude-code install dir is read-only (auto-updater protection) ---
CC_INSTALL_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"
INSTALLED_VER=$(claude --version 2>/dev/null | head -1 | awk '{print $1}')
if [ -d "$CC_INSTALL_DIR" ] && [ "$(stat -c '%A' "$CC_INSTALL_DIR" 2>/dev/null | cut -c1-4)" = "dr-x" ]; then
  if [ -n "$INSTALLED_VER" ]; then
    row 12 "Install dir read-only" PASS "auto-updater cannot overwrite version $INSTALLED_VER"
  else
    row 12 "Install dir read-only" PASS "auto-updater cannot overwrite installed version"
  fi
elif [ ! -d "$CC_INSTALL_DIR" ]; then
  row 12 "Install dir read-only" WARN "claude-code not installed at $CC_INSTALL_DIR"
else
  row 12 "Install dir read-only" WARN "directory is writable; the auto-updater can clobber the pin (re-run install.sh)"
fi

# --- 13. Termux:API ---
if command -v termux-battery-status >/dev/null 2>&1; then
  row 13 "Termux:API installed" PASS "termux-battery-status on PATH"
else
  row 13 "Termux:API installed" WARN "missing (notifications, clipboard, sensors, etc. will not work)"
fi

# --- Summary ---

echo ""
echo "Summary: $PASSES PASS, $WARNS WARN, $FAILS FAIL"
if [ "$FAILS" -gt 0 ]; then
  echo ""
  echo "One or more checks FAILED. Fix recommendations:"
  echo "  - If 'Claude Code installed' failed: run bash install.sh"
  echo "  - If 'Grep/Glob fix' failed: echo 'export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1' >> ~/.bashrc"
  echo "  - If 'TMPDIR set' failed: export TMPDIR=\$PREFIX/tmp"
  echo "  - If 'Node.js version' failed: pkg upgrade nodejs"
  exit 1
fi
exit 0
