#!/usr/bin/env bash
# Claude Code on Android: One-Command Installer
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
#   4. Updates package index and installs packages (nodejs, git, curl, proot, ripgrep, termux-api, jq)
#   5. Installs Claude Code via npm, PINNED to the last working version on Termux
#      (see anthropics/claude-code#50270; versions 2.1.113+ ship as native binaries
#      with no android-arm64 build, breaking native Termux installs)
#   6. Locks the install dir against the in-process auto-updater (chmod -R a-w)
#   7. Sets DISABLE_AUTOUPDATER=1 in shell + ~/.claude/settings.json
#   8. Creates the arm64-android ripgrep symlink
#   9. Configures shell (TMPDIR, CLAUDE_CODE_USE_NATIVE_FILE_SEARCH, launch alias)
#
# Re-run safe: every step is idempotent.
#
# What this script does NOT do:
#   - Require root (there is none)
#   - Modify system files
#   - Install a guest OS
#   - Send any data anywhere

set -euo pipefail

# --- Pinned version ---
# Last upstream version with the bundled cli.js entry that runs on android-arm64.
# 2.1.113 switched to native-binary distribution which excludes android.
# Tracking upstream: https://github.com/anthropics/claude-code/issues/50270
CC_PIN="2.1.112"

# --- Helpers ---

info()  { printf '\033[0;36m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[0;33m[warn]\033[0m  %s\n' "$1"; }
fail()  { printf '\033[0;31m[fail]\033[0m  %s\n' "$1"; exit 1; }

# --- Preflight ---

info "Claude Code on Android: Installer (Path A, pinned to v${CC_PIN})"
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

info "Installing packages (nodejs, git, curl, proot, ripgrep, termux-api, jq)..."
pkg install nodejs git curl proot ripgrep termux-api jq -y || fail "Package installation failed. Check your internet connection."

# Verify Node.js version
NODE_VER=$(node -v 2>/dev/null || echo "none")
NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR" -lt 25 ] 2>/dev/null; then
  warn "Node.js $NODE_VER detected. v25+ is required (v24 hangs on ARM64)."
  warn "Run: pkg upgrade nodejs"
else
  ok "Node.js $NODE_VER"
fi

# --- Step 3: Install Claude Code (pinned + auto-updater disabled) ---

CC_DIR="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"

# Detect existing install state and recover if broken
if [ -f "$CC_DIR/package.json" ]; then
  EXISTING_VER=$(node -e "console.log(require('$CC_DIR/package.json').version)" 2>/dev/null || echo "unknown")
  info "Existing claude-code install detected: v${EXISTING_VER}"

  # Always restore +w before any reinstall (chmod -R a-w from prior run blocks npm)
  chmod -R u+w "$CC_DIR" 2>/dev/null || true

  if [ "$EXISTING_VER" = "$CC_PIN" ]; then
    info "Already on pinned version v${CC_PIN}. Skipping reinstall."
    SKIP_INSTALL=1
  else
    info "Replacing v${EXISTING_VER} with pinned v${CC_PIN}..."
    SKIP_INSTALL=0
  fi
else
  SKIP_INSTALL=0
fi

if [ "$SKIP_INSTALL" -eq 0 ]; then
  info "Installing Claude Code v${CC_PIN} with auto-updater disabled..."
  DISABLE_AUTOUPDATER=1 npm install -g "@anthropic-ai/claude-code@${CC_PIN}" \
    || fail "npm install failed. Check TMPDIR and internet connection."
fi

# Verify the install actually works (cli.js entry, returns version)
CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "")
if [ -z "$CLAUDE_VER" ] || [[ "$CLAUDE_VER" == *"not installed"* ]]; then
  fail "Claude Code did not launch cleanly after install. Check 'claude --version' output."
fi
ok "Claude Code installed: ${CLAUDE_VER}"

# --- Step 4: Lock install dir against the in-process auto-updater ---
# Without this, the running claude session will silently re-fetch latest within
# minutes and clobber the pin. See daniel-thisnow's comment on
# anthropics/claude-code#50270; the chmod is load-bearing.

info "Locking install dir against the auto-updater..."
chmod -R a-w "$CC_DIR"
ok "Install dir is read-only (rerun this script to upgrade later)"

# --- Step 5: Fix ripgrep ---

info "Setting up ripgrep for Grep/Glob tools..."
VENDOR_DIR="$CC_DIR/vendor/ripgrep"
if [ -d "$VENDOR_DIR" ]; then
  # Need write back briefly to land the symlink
  chmod -R u+w "$CC_DIR" 2>/dev/null || true
  mkdir -p "$VENDOR_DIR/arm64-android"
  ln -sf "$(command -v rg)" "$VENDOR_DIR/arm64-android/rg"
  chmod -R a-w "$CC_DIR"
  ok "ripgrep symlink created (CLAUDE_CODE_USE_NATIVE_FILE_SEARCH below also covers this)"
else
  warn "Could not find vendor directory. Run /fix-ripgrep inside Claude Code later."
fi

# --- Step 6: Configure shell ---

# Add TMPDIR if not already in .bashrc
if ! grep -q 'TMPDIR=\$PREFIX/tmp' ~/.bashrc 2>/dev/null; then
  printf '\n# Claude Code on Android\nexport TMPDIR=$PREFIX/tmp\n' >> ~/.bashrc
  ok "TMPDIR added to ~/.bashrc"
else
  ok "TMPDIR already in ~/.bashrc"
fi

# Add CLAUDE_CODE_USE_NATIVE_FILE_SEARCH (durable ripgrep fix that survives updates)
if ! grep -q 'CLAUDE_CODE_USE_NATIVE_FILE_SEARCH' ~/.bashrc 2>/dev/null; then
  printf '\n# Use system ripgrep instead of bundled (survives Claude Code updates)\nexport CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1\n' >> ~/.bashrc
  ok "CLAUDE_CODE_USE_NATIVE_FILE_SEARCH added to ~/.bashrc"
else
  ok "CLAUDE_CODE_USE_NATIVE_FILE_SEARCH already in ~/.bashrc"
fi

# Add DISABLE_AUTOUPDATER (belt-and-braces against the in-process updater)
if ! grep -q 'DISABLE_AUTOUPDATER' ~/.bashrc 2>/dev/null; then
  printf '\n# Block claude-code auto-updater (would otherwise pull broken 2.1.113+; see anthropics/claude-code#50270)\nexport DISABLE_AUTOUPDATER=1\n' >> ~/.bashrc
  ok "DISABLE_AUTOUPDATER added to ~/.bashrc"
else
  ok "DISABLE_AUTOUPDATER already in ~/.bashrc"
fi

# Add the launch alias
ALIAS_LINE="alias claude-android='proot -b \$PREFIX/tmp:/tmp claude'"
if ! grep -q 'claude-android' ~/.bashrc 2>/dev/null; then
  echo "$ALIAS_LINE" >> ~/.bashrc
  ok "claude-android alias added to ~/.bashrc"
else
  ok "claude-android alias already in ~/.bashrc"
fi

# --- Step 7: Merge env.DISABLE_AUTOUPDATER into ~/.claude/settings.json ---

mkdir -p ~/.claude
SETTINGS=~/.claude/settings.json
SETTINGS_REAL=$(readlink -f "$SETTINGS" 2>/dev/null || echo "$SETTINGS")

if [ ! -f "$SETTINGS_REAL" ]; then
  echo '{"env":{"DISABLE_AUTOUPDATER":"1"}}' > "$SETTINGS_REAL"
  ok "Created $SETTINGS with DISABLE_AUTOUPDATER"
else
  if jq -e '.env.DISABLE_AUTOUPDATER == "1"' "$SETTINGS_REAL" >/dev/null 2>&1; then
    ok "settings.json already has env.DISABLE_AUTOUPDATER"
  else
    cp -p "$SETTINGS_REAL" "${SETTINGS_REAL}.bak.$(date +%s)"
    TMP=$(mktemp)
    jq '. as $orig | (.env // {}) + {"DISABLE_AUTOUPDATER":"1"} as $newenv | $orig + {"env": $newenv}' \
      "$SETTINGS_REAL" > "$TMP" && mv "$TMP" "$SETTINGS_REAL"
    ok "Merged env.DISABLE_AUTOUPDATER into settings.json (backup saved)"
  fi
fi

# --- Done ---

echo ""
echo "════════════════════════════════════════════"
echo ""
echo "  Claude Code v${CC_PIN} is installed and locked."
echo ""
echo "  To launch:"
echo "    proot -b \$PREFIX/tmp:/tmp claude"
echo ""
echo "  Or reload your shell and use the alias:"
echo "    source ~/.bashrc"
echo "    claude-android"
echo ""
echo "  Why pinned: claude-code 2.1.113+ is broken on native Termux."
echo "  Tracking:   https://github.com/anthropics/claude-code/issues/50270"
echo ""
echo "  To upgrade later (when upstream restores android-arm64 support):"
echo "    chmod -R u+w $CC_DIR"
echo "    npm install -g @anthropic-ai/claude-code@<new-version>"
echo "    chmod -R a-w $CC_DIR"
echo ""
echo "  First launch will ask you to authenticate"
echo "  with your Anthropic account."
echo ""
echo "  Guide:  https://github.com/ferrumclaudepilgrim/claude-code-android"
echo "  Issues: https://github.com/ferrumclaudepilgrim/claude-code-android/issues"
echo ""
echo "════════════════════════════════════════════"
