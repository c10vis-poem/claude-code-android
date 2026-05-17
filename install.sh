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
# Three layers, all needed empirically:
#  1. chmod -R a-w on the install dir (slows the updater; insufficient alone
#     because the updater can chmod +w before writing)
#  2. DISABLE_AUTOUPDATER=1 in ~/.bashrc (every shell that launches claude
#     inherits the env)
#  3. env.DISABLE_AUTOUPDATER=1 in ~/.claude/settings.json (inside a running
#     claude session this is what stops the in-process updater from firing)
#
# v2.7.0 had layers 2+3. v2.8.0 dropped them as "belt-and-braces" and the
# pin was clobbered within minutes of a real claude session starting. v2.8.1
# restores them. The CHANGELOG framing in [2.8.0] was empirically wrong.

info "Locking install directory against the auto-updater..."
chmod -R a-w "$CC_DIR"
ok "Install directory is read-only."

info "Persisting DISABLE_AUTOUPDATER=1 to ~/.bashrc..."
BASHRC="$HOME/.bashrc"
[ -f "$BASHRC" ] || touch "$BASHRC"
if ! grep -q '^export DISABLE_AUTOUPDATER=1' "$BASHRC" 2>/dev/null; then
    echo 'export DISABLE_AUTOUPDATER=1' >> "$BASHRC"
fi
ok "DISABLE_AUTOUPDATER=1 in ~/.bashrc"

info "Merging env.DISABLE_AUTOUPDATER into ~/.claude/settings.json..."
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
node -e "
const fs = require('fs');
const p = '$SETTINGS';
let s = {};
try { s = JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) {}
s.env = s.env || {};
s.env.DISABLE_AUTOUPDATER = '1';
fs.writeFileSync(p, JSON.stringify(s, null, 2));
" || fail "settings.json merge failed."
ok "env.DISABLE_AUTOUPDATER=1 in ~/.claude/settings.json"

# --- Done ---

echo ""
echo "Done. Run: claude"
echo ""
echo "  Pinned to v${CC_PIN} because upstream 2.1.113+ ships native binaries"
echo "  with no android-arm64 build. Tracking: anthropics/claude-code#50270"
echo ""
echo "  Re-run this script to upgrade when upstream restores the build."
