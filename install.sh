#!/usr/bin/env bash
# Claude Code on Android: bare-minimum Path A installer (native Termux).
# https://github.com/ferrumclaudepilgrim/claude-code-android
#
# Installs the minimum needed for `claude` to launch and stay launched on
# native Termux (aarch64 Android). Pins to 2.1.112, the last upstream
# version with a working android-arm64 build; locks the install directory
# read-only so the in-process auto-updater cannot clobber it.
# Tracking upstream: https://github.com/anthropics/claude-code/issues/50270
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh | bash
#
# Or download and inspect first (recommended):
#   curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
#   less install.sh
#   bash install.sh
#
# Re-run safe: every step is idempotent.

set -euo pipefail

CC_PIN="2.1.112"
CC_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"

info()  { printf '\033[0;36m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$1"; }
fail()  { printf '\033[0;31m[fail]\033[0m  %s\n' "$1"; exit 1; }

# --- Preflight ---

if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-}/tmp" ]; then
    fail "Run this from inside Termux. Install Termux from F-Droid (not the Play Store)."
fi

ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    fail "aarch64 (64-bit ARM) is required. uname -m reports: $ARCH"
fi

ok "Running in Termux on aarch64"

# --- Install Node.js ---

info "Updating package index..."
pkg update -y || fail "pkg update failed. If 'pkg' hangs or returns 'Failed to fetch', the auto-selected Termux mirror may be slow. Run: termux-change-repo  (pick a different mirror), then re-run this script."

info "Installing Node.js..."
pkg install nodejs -y || fail "pkg install nodejs failed."
ok "Node.js $(node -v) installed"

# --- Install Claude Code (pinned) ---

# TMPDIR is required for the install step itself (npm needs a writable temp dir).
export TMPDIR="$PREFIX/tmp"

# If a prior install left the directory locked read-only, restore write so npm can replace it.
[ -d "$CC_DIR" ] && chmod -R u+w "$CC_DIR" 2>/dev/null || true

info "Installing Claude Code v${CC_PIN} (the last upstream version with a working android-arm64 build)..."
DISABLE_AUTOUPDATER=1 npm install -g "@anthropic-ai/claude-code@${CC_PIN}" \
    || fail "npm install failed."

CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || true)
[ -n "$CLAUDE_VER" ] && [[ "$CLAUDE_VER" != *"not installed"* ]] \
    || fail "Claude Code did not launch cleanly after install. 'claude --version' returned: $CLAUDE_VER"
ok "Claude Code installed: $CLAUDE_VER"

# --- Lock against the in-process auto-updater ---
# Without this, the running claude session re-fetches 'latest' (no android-arm64
# binary in 2.1.113+; upstream #50270) within minutes and overwrites this install.
# The chmod is what actually holds; DISABLE_AUTOUPDATER alone is not sufficient.

info "Locking install directory against the auto-updater..."
chmod -R a-w "$CC_DIR"
ok "Install directory is read-only. Re-run this script to upgrade later."

# --- Done ---

echo ""
echo "Done. Run: claude"
echo ""
echo "  Pinned to v${CC_PIN} because upstream 2.1.113+ ships native binaries"
echo "  with no android-arm64 build. Tracking: anthropics/claude-code#50270"
echo ""
echo "  Re-run this script to upgrade when upstream restores the build."
