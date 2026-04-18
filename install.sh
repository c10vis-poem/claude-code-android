#!/usr/bin/env bash
# Claude Code on Android — One-Command Installer
# https://github.com/ferrumclaudepilgrim/claude-code-android
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh | bash
#
# Or download and inspect first (recommended):
#   curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/install.sh -o install.sh
#   less install.sh
#   bash install.sh
#
# What this script does:
#   1. Checks you're running in Termux (not inside proot)
#   2. Checks architecture is aarch64
#   3. Sets TMPDIR for npm
#   4. Updates package index and installs packages (nodejs, git, curl, proot, ripgrep, termux-api)
#   5. Installs Claude Code via npm
#   6. Creates the arm64-android ripgrep symlink
#   7. Configures shell (TMPDIR, CLAUDE_CODE_USE_NATIVE_FILE_SEARCH, launch alias)
#
# What this script does NOT do:
#   - Require root (there is none)
#   - Modify system files
#   - Install a guest OS
#   - Send any data anywhere

set -euo pipefail

# --- Helpers ---

info()  { printf '\033[0;36m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[0;33m[warn]\033[0m  %s\n' "$1"; }
fail()  { printf '\033[0;31m[fail]\033[0m  %s\n' "$1"; exit 1; }

# --- Preflight ---

info "Claude Code on Android — Installer"
echo ""

# Check we're in Termux
if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-}/tmp" ]; then
  fail "This script must be run inside Termux. Install Termux from F-Droid (not Play Store)."
fi

# Check we're NOT inside proot already
TRACER_PID=$(grep TracerPid "/proc/$$/status" 2>/dev/null | cut -d $'\t' -f 2 || echo "0")
if [ "$TRACER_PID" != "0" ]; then
  fail "You're inside a proot session. Exit it first, then run this script directly in Termux."
fi

ok "Running in Termux"

# --- Architecture check ---
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
  fail "Unsupported architecture: $ARCH. Claude Code requires aarch64 (64-bit ARM)."
fi
ok "Architecture: $ARCH"

# --- Step 1: Set TMPDIR ---

export TMPDIR="$PREFIX/tmp"
ok "TMPDIR set to $TMPDIR"

# --- Step 2: Install packages ---

info "Updating package index..."
pkg update -y || fail "pkg update failed. Check your internet connection."

info "Installing packages (nodejs, git, curl, proot, ripgrep, termux-api)..."
pkg install nodejs git curl proot ripgrep termux-api -y || fail "Package installation failed. Check your internet connection."

# Verify Node.js version
NODE_VER=$(node -v 2>/dev/null || echo "none")
NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR" -lt 25 ] 2>/dev/null; then
  warn "Node.js $NODE_VER detected. v25+ is required (v24 hangs on ARM64)."
  warn "Run: pkg upgrade nodejs"
else
  ok "Node.js $NODE_VER"
fi

# --- Step 3: Install Claude Code ---

info "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code || fail "npm install failed. Check TMPDIR and internet connection."

CLAUDE_VER=$(node "$PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs" --version 2>/dev/null || echo "unknown")
ok "Claude Code $CLAUDE_VER installed (using cli-wrapper.cjs JS fallback; android-arm64 native binary not shipped upstream)"

# --- Step 4: Fix ripgrep ---

info "Setting up ripgrep for Grep/Glob tools..."
VENDOR_DIR="$(dirname "$(command -v claude)")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
if [ -d "$VENDOR_DIR" ]; then
  mkdir -p "$VENDOR_DIR/arm64-android"
  ln -sf "$(command -v rg)" "$VENDOR_DIR/arm64-android/rg"
  ok "ripgrep symlink created"
else
  warn "Could not find vendor directory. Run /fix-ripgrep inside Claude Code later."
fi

# --- Step 5: Configure shell ---

ALIAS_LINE="alias claude-android='proot -b \$PREFIX/tmp:/tmp node \$PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs'"
TMPDIR_LINE="export TMPDIR=\$PREFIX/tmp"

# Add TMPDIR if not already in .bashrc
if ! grep -q 'TMPDIR=\$PREFIX/tmp' ~/.bashrc 2>/dev/null; then
  echo "" >> ~/.bashrc
  echo "# Claude Code on Android" >> ~/.bashrc
  echo "$TMPDIR_LINE" >> ~/.bashrc
  ok "TMPDIR added to .bashrc"
else
  ok "TMPDIR already in .bashrc"
fi

# Add CLAUDE_CODE_USE_NATIVE_FILE_SEARCH if not already in .bashrc
NATIVE_SEARCH_LINE="export CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1"
if ! grep -q 'CLAUDE_CODE_USE_NATIVE_FILE_SEARCH' ~/.bashrc 2>/dev/null; then
  echo "" >> ~/.bashrc
  echo "# Use system ripgrep instead of bundled (survives Claude Code updates)" >> ~/.bashrc
  echo "$NATIVE_SEARCH_LINE" >> ~/.bashrc
  ok "Added CLAUDE_CODE_USE_NATIVE_FILE_SEARCH to ~/.bashrc"
else
  ok "CLAUDE_CODE_USE_NATIVE_FILE_SEARCH already in ~/.bashrc"
fi

# Add alias if not already in .bashrc
if ! grep -q 'claude-android' ~/.bashrc 2>/dev/null; then
  echo "$ALIAS_LINE" >> ~/.bashrc
  ok "claude-android alias added to .bashrc"
else
  ok "claude-android alias already in .bashrc"
fi

# --- Done ---

echo ""
echo "════════════════════════════════════════════"
echo ""
echo "  Claude Code is installed."
echo ""
echo "  To launch:"
echo "    proot -b \$PREFIX/tmp:/tmp node \$PREFIX/lib/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs"
echo ""
echo "  Or reload your shell and use the alias:"
echo "    source ~/.bashrc"
echo "    claude-android"
echo ""
echo "  First launch will ask you to authenticate"
echo "  with your Anthropic account."
echo ""
echo "  Guide:  https://github.com/ferrumclaudepilgrim/claude-code-android"
echo "  Issues: https://github.com/ferrumclaudepilgrim/claude-code-android/issues"
echo ""
echo "════════════════════════════════════════════"
