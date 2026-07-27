#!/usr/bin/env bash
# fix-ripgrep.sh: Recover Claude Code's Grep/Glob tools when the bundled
#                   ripgrep is missing the arm64-android binary.
#
# Background: on the v2.x / pinned 2.1.112 install, Claude Code bundles
# platform-specific ripgrep binaries in its vendor directory but does NOT
# include an `arm64-android` variant. This causes the Grep, Glob, and
# slash-command tools to fail with:
#
#     spawn .../vendor/ripgrep/arm64-android/rg ENOENT
#     (ENOENT = no such file or directory)
#
# The native Path A install (the current 2.9.x architecture) is not affected:
# it ships vendor/ripgrep/arm64-linux/rg and reports process.platform ===
# 'linux', so it finds its bundled rg with no symlink or env var needed.
#
# The fix: install `ripgrep` via pkg and symlink the system binary onto the
# exact vendored path Claude Code looks for. That is what THIS script does.
# On 2.1.112 the CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1 env var does NOT
# redirect the search (verified on device: with the symlink removed, Grep
# fails with the same ENOENT whether the flag is set in ~/.bashrc, exported
# in the shell, or set in settings.json env). The symlink is what works.
#
# The symlink does not survive a Claude Code update; re-run this script after
# you upgrade. Upstream tracking: anthropics/claude-code#13021 (Closed).
#
# Usage:
#   bash scripts/fix-ripgrep.sh
#
# Exit codes:
#   0 = success (symlink in place, Grep should now work)
#   1 = could not locate Claude Code install directory
#   2 = ripgrep install failed
#   3 = symlink creation failed

set -euo pipefail

# --- 1. Detect Claude Code install directory ---

CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
if [ -z "$CLAUDE_BIN" ]; then
  echo "ERROR: 'claude' binary not on PATH. Install Claude Code first." >&2
  exit 1
fi

# The pinned package always installs to $PREFIX/lib/node_modules, the same
# path install-pinned.sh, install.sh, and migrate.sh use. Derive it directly;
# readlink -f on $PREFIX/bin/claude resolves into the package (cli.js), so a
# relative ../lib/node_modules walk from there double-nests to a path that
# does not exist.
CLAUDE_PKG="${PREFIX:-/data/data/com.termux/files/usr}/lib/node_modules/@anthropic-ai/claude-code"
VENDOR_DIR="$CLAUDE_PKG/vendor/ripgrep"
if [ ! -d "$VENDOR_DIR" ]; then
  echo "ERROR: vendor directory not found at $VENDOR_DIR" >&2
  echo "       (Claude Code may have changed its layout; check the install path.)" >&2
  exit 1
fi
echo "[info]  Vendor directory: $VENDOR_DIR"

# --- 2. Check if the fix is already in place ---

if [ -e "$VENDOR_DIR/arm64-android/rg" ]; then
  echo "[ok]    arm64-android/rg already present (symlink or binary)"
  EXISTING_TARGET="$(readlink -f "$VENDOR_DIR/arm64-android/rg" 2>/dev/null || echo unknown)"
  echo "[info]  Resolves to: $EXISTING_TARGET"
  echo "[info]  Nothing to do."
  exit 0
fi

# --- 3. Install system ripgrep if needed ---

if ! command -v rg >/dev/null 2>&1; then
  echo "[info]  ripgrep not installed; installing via pkg..."
  pkg install ripgrep -y || { echo "ERROR: pkg install ripgrep failed" >&2; exit 2; }
fi
RG_PATH="$(command -v rg)"
echo "[ok]    System ripgrep: $RG_PATH"

# --- 4. Restore write permission and create the symlink ---

# Claude Code's vendor directory may be write-locked (by Claude Code's
# own installer or a prior run of this script). Flip that off briefly
# to land the symlink, then re-lock below.
CC_DIR="$(dirname "$VENDOR_DIR")"
chmod -R u+w "$CC_DIR" 2>/dev/null || true

mkdir -p "$VENDOR_DIR/arm64-android" || { echo "ERROR: mkdir failed" >&2; exit 3; }
ln -sf "$RG_PATH" "$VENDOR_DIR/arm64-android/rg" || { echo "ERROR: symlink failed" >&2; exit 3; }

# Re-lock the install dir.
chmod -R a-w "$CC_DIR"

echo "[ok]    Symlink created: $VENDOR_DIR/arm64-android/rg -> $RG_PATH"
echo ""
echo "Verify by running the Grep tool inside Claude Code. If you still see"
echo "ENOENT errors, check that the path in the error message matches"
echo "$VENDOR_DIR/arm64-android/rg (the vendored layout may have changed)."
