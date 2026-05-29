#!/data/data/com.termux/files/usr/bin/bash
# claude-code-android installer (Termux on aarch64 Android).
#
# Installs Anthropic's official linux-arm64 claude binary, patched via
# glibc-runner so it runs under Android's bionic kernel. A wrapper at
# $PREFIX/bin/claude auto-checks for new versions once per day on launch
# (--update-now forces an immediate check) and re-patches if needed.
#
# Two yes/no questions up front, then unattended. Approx 5-10 minutes
# depending on connection. The first download is ~233 MB.
#
# Re-running this script is not supported. It is a fresh-install path.
# If you need to update claude, that happens automatically through the
# wrapper. If you want to start over, run termux-reset then re-run.
#
# Tracking the upstream issue this works around:
#   https://github.com/anthropics/claude-code/issues/50270

set -euo pipefail

info(){ printf '\033[0;36m[info]\033[0m  %s\n' "$1"; }
ok(){   printf '\033[0;32m[ok]\033[0m    %s\n' "$1"; }
fail(){ printf '\033[0;31m[fail]\033[0m  %s\n' "$1" >&2; exit 1; }

# --- Preflight ---
[ -z "${PREFIX:-}" ] && fail "PREFIX unset. Run this inside Termux, not adb shell."
[ "$(uname -m)" = "aarch64" ] || fail "aarch64 only. uname -m reports: $(uname -m)"

# --- Existing-install detection: hand off, do not clobber ---
# This is the fresh-install path. If claude is already present, route the user
# instead of overwriting their setup.
CC_NPM_PKG="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"
CC_BINLINK="$PREFIX/bin/claude"
CC_VERSIONS="$HOME/.local/share/claude/versions"
if [ -d "$CC_VERSIONS" ] && ls "$CC_VERSIONS"/*.*.* >/dev/null 2>&1 && [ -f "$CC_BINLINK" ] && [ ! -L "$CC_BINLINK" ]; then
  ok "claude is already installed via the v2.9.0 wrapper. Nothing to do here."
  info "The wrapper auto-updates daily. Force a check now with: claude --update-now"
  exit 0
fi
if [ -d "$CC_NPM_PKG" ] || { [ -L "$CC_BINLINK" ] && readlink "$CC_BINLINK" | grep -q 'node_modules/@anthropic-ai/claude-code'; }; then
  info "An older pinned v2.x install is present."
  info "To upgrade WITHOUT losing your sessions, login, or settings, use the"
  info "migration script instead of this installer:"
  printf '\n    curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/migrate.sh -o migrate.sh\n    bash migrate.sh\n\n'
  info "This installer is fresh-only and will not overwrite an existing install."
  exit 0
fi

cat <<BANNER

  claude-code-android installer
  =============================
  Two yes/no questions up front, then unattended install (5-10 minutes).
  When it finishes, you'll type 'claude' to start.

BANNER

# --- Q1: Fresh Termux? ---
cat <<'Q1'
Q1. Is this a fresh Termux install?

  Brand new Termux installs need their package index brought up to date
  before installing anything else. The script will run pkg update + pkg
  upgrade, taking the new defaults for any system config files that ship
  updates. Safe on a fresh Termux: nothing of yours to lose yet.

  If you have been using Termux a while and customized system configs
  under $PREFIX/etc/ (sshd_config, openssl.cnf, etc.), say no and the
  script will keep your changes during the upgrade.

  This choice applies only to THIS install run. It does NOT change how
  your future pkg upgrade commands behave.

Q1
read -r -p "Fresh Termux? [Y/n] " Q1
Q1="${Q1:-Y}"
case "${Q1,,}" in
  y|yes) FRESH=1 ;;
  n|no)  FRESH=0 ;;
  *) fail "Q1: answer 'y' or 'n'; got '$Q1'" ;;
esac
ok "Q1: $([ $FRESH = 1 ] && echo fresh || echo keep)"
echo

# --- Q2: Recommended packages? ---
cat <<'Q2'
Q2. Install recommended packages?

  Claude Code launches with just the patched binary, but many of its
  built-in tools assume common Linux utilities exist. Without these you
  will hit "command not found" errors when:

    - The Bash tool tries to run git, curl, jq, python, make
    - Claude tries to clone a repo, build with clang, or parse JSON
    - You want SSH from inside a Claude session (openssh client)

  These are the same utilities a typical PC running Claude Code already
  has. Without them on Termux, you spend the first hour hitting
  "pkg install <thing>" prompts.

  Packages: git, gh, wget, jq, python, openssh, tree, proot, termux-api,
  proot-distro, make, clang, file, xxd, htop, bat, fzf (17 packages,
  roughly 200 MB additional disk).

Q2
read -r -p "Install recommended packages? [Y/n] " Q2
Q2="${Q2:-Y}"
case "${Q2,,}" in
  y|yes) RECOMMENDED=1 ;;
  n|no)  RECOMMENDED=0 ;;
  *) fail "Q2: answer 'y' or 'n'; got '$Q2'" ;;
esac
ok "Q2: $([ $RECOMMENDED = 1 ] && echo yes || echo no)"
echo

# --- Sanity: clean state ---
[ -d "$PREFIX/glibc" ]                 && fail "\$PREFIX/glibc already exists. Run 'termux-reset' for a clean install."
[ -e "$PREFIX/bin/claude" ]            && fail "\$PREFIX/bin/claude already exists. This installer is fresh-only."
[ -e "$HOME/.local/share/claude" ]     && fail "\$HOME/.local/share/claude already exists. This installer is fresh-only."
[ -e "$HOME/.claude" ]                 && fail "\$HOME/.claude already exists. This installer is fresh-only."
ok "clean state confirmed"

# --- apt non-interactive options based on Q1 ---
export DEBIAN_FRONTEND=noninteractive
if [ "$FRESH" = 1 ]; then
  PKG_OPTS="-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew"
else
  PKG_OPTS="-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
fi

# --- Termux: bring base packages current ---
info "pkg update"
pkg update $PKG_OPTS >/dev/null || fail "pkg update failed"

info "pkg upgrade (fixes any bootstrap/current library mismatches)"
pkg upgrade $PKG_OPTS >/dev/null || fail "pkg upgrade failed"

info "pkg install curl jq"
pkg install $PKG_OPTS curl jq >/dev/null || fail "pkg install curl/jq failed"
ok "base tools installed"

# --- glibc-runner + patchelf-glibc ---
info "pkg install glibc-repo (enables Termux glibc-packages source)"
pkg install $PKG_OPTS glibc-repo >/dev/null || fail "glibc-repo install failed"
pkg update $PKG_OPTS >/dev/null || fail "pkg update after glibc-repo failed"

info "pkg install glibc-runner patchelf-glibc (~50 MB download)"
pkg install $PKG_OPTS glibc-runner patchelf-glibc >/dev/null || fail "glibc-runner install failed"

PATCHELF="$PREFIX/glibc/bin/patchelf"
GLIBC_LD="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
[ -x "$PATCHELF" ] || fail "patchelf not found at $PATCHELF after install"
[ -f "$GLIBC_LD" ] || fail "glibc ld.so not found at $GLIBC_LD after install"
ok "glibc-runner + patchelf installed"

# --- Resolve latest claude version, download, verify, patch ---
info "resolving latest claude version from npm registry"
LATEST="$(curl -fsSL --max-time 10 https://registry.npmjs.org/@anthropic-ai/claude-code/latest 2>/dev/null | jq -r .version 2>/dev/null)"
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
  fail "could not query npm registry for the latest claude version"
fi
ok "latest claude version: $LATEST"

VERSIONS_DIR="$HOME/.local/share/claude/versions"
BINARY="$VERSIONS_DIR/$LATEST"
WRAPPER="$PREFIX/bin/claude"
mkdir -p "$VERSIONS_DIR" "$HOME/.claude"

DL_BASE="https://downloads.claude.ai/claude-code-releases/$LATEST"

info "downloading $LATEST linux-arm64 binary (~233 MB)"
curl -fsSL --max-time 300 "$DL_BASE/linux-arm64/claude" -o "$BINARY.tmp" \
  || fail "binary download failed"

info "verifying checksum against published manifest"
EXP="$(curl -fsSL --max-time 10 "$DL_BASE/manifest.json" 2>/dev/null | jq -er '.platforms["linux-arm64"].checksum' 2>/dev/null || true)"
ACT="$(sha256sum "$BINARY.tmp" | cut -d' ' -f1)"
if [ -z "$EXP" ]; then
  rm -f "$BINARY.tmp"
  fail "could not read checksum from manifest"
fi
if [ "$EXP" != "$ACT" ]; then
  rm -f "$BINARY.tmp"
  fail "checksum mismatch: expected $EXP, got $ACT"
fi
ok "checksum verified"

chmod +x "$BINARY.tmp"
LD_PRELOAD='' "$PATCHELF" --set-interpreter "$GLIBC_LD" "$BINARY.tmp" \
  || fail "patchelf failed to set ELF interpreter"
mv "$BINARY.tmp" "$BINARY"
ok "binary patched and installed at $BINARY"

# --- ~/.claude/settings.json ---
# autoUpdates:false disables claude's in-process updater. The wrapper
# handles updates instead. env.LD_PRELOAD restores Termux's syscall
# shim for subprocesses claude spawns (Bash tool, npm, etc.).
cat > "$HOME/.claude/settings.json" <<EOF
{
  "autoUpdates": false,
  "env": {
    "LD_PRELOAD": "$PREFIX/lib/libtermux-exec-ld-preload.so"
  }
}
EOF
ok "settings.json written"

# --- Wrapper at $PREFIX/bin/claude ---
# Once per 24h on launch, checks npm for a newer version. If found,
# downloads, verifies checksum, patchelfs, swaps. --update-now forces
# an immediate check, bypassing the rate limit. Any failure (network,
# checksum, patchelf) is reported to stderr and the cached binary is
# used. Self-heals the ELF interpreter every launch. Unsets LD_PRELOAD
# before exec so the glibc binary doesn't crash on libtermux-exec's
# unversioned libc.so dependency.
cat > "$WRAPPER" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
VERSIONS_DIR="$VERSIONS_DIR"
GLIBC_LD="$GLIBC_LD"
PATCHELF="$PATCHELF"
STAMP="\$VERSIONS_DIR/.last-update-check"
RATE_LIMIT=86400

force_update=0
args=()
for a in "\$@"; do
  if [ "\$a" = "--update-now" ]; then
    force_update=1
  else
    args+=("\$a")
  fi
done

should_check=0
if [ "\$force_update" = 1 ]; then
  should_check=1
elif [ ! -f "\$STAMP" ]; then
  should_check=1
else
  now=\$(date +%s)
  last=\$(stat -c%Y "\$STAMP" 2>/dev/null || echo 0)
  [ \$((now - last)) -ge \$RATE_LIMIT ] && should_check=1
fi

if [ "\$should_check" = 1 ]; then
  latest=\$(curl -fsSL --max-time 5 https://registry.npmjs.org/@anthropic-ai/claude-code/latest 2>/dev/null | jq -r .version 2>/dev/null || echo "")
  if [ -n "\$latest" ] && [ "\$latest" != "null" ]; then
    new_bin="\$VERSIONS_DIR/\$latest"
    if [ ! -f "\$new_bin" ]; then
      dl="https://downloads.claude.ai/claude-code-releases/\$latest"
      if curl -fsSL --max-time 300 "\$dl/linux-arm64/claude" -o "\$new_bin.tmp" 2>/dev/null; then
        exp=\$(curl -fsSL --max-time 5 "\$dl/manifest.json" 2>/dev/null | jq -er '.platforms["linux-arm64"].checksum' 2>/dev/null || echo "")
        act=\$(sha256sum "\$new_bin.tmp" | cut -d' ' -f1)
        if [ -n "\$exp" ] && [ "\$exp" = "\$act" ]; then
          chmod +x "\$new_bin.tmp"
          if LD_PRELOAD= "\$PATCHELF" --set-interpreter "\$GLIBC_LD" "\$new_bin.tmp" 2>/dev/null; then
            mv "\$new_bin.tmp" "\$new_bin"
            # Retain N-1 (latest + previous) for rollback. If the new \$latest
            # ships broken, "rm versions/\$latest && claude --update-now" puts
            # you back on the prior known-good binary.
            prev=\$(ls -1 "\$VERSIONS_DIR" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\$' | sort -V | tail -2 | head -1)
            for old in "\$VERSIONS_DIR"/*; do
              base=\$(basename "\$old")
              [ -f "\$old" ] && [ "\$base" != "\$latest" ] && [ "\$base" != "\$prev" ] && rm -f "\$old"
            done
          else
            rm -f "\$new_bin.tmp"
            echo "[claude] update: patchelf failed on \$latest, using cached" >&2
          fi
        else
          rm -f "\$new_bin.tmp"
          echo "[claude] update: checksum mismatch on \$latest, using cached" >&2
        fi
      else
        echo "[claude] update: download failed, using cached" >&2
      fi
    fi
  else
    echo "[claude] update: could not query npm registry, using cached" >&2
  fi
  touch "\$STAMP"
fi

# Pick the highest installed version
bin=\$(ls -1 "\$VERSIONS_DIR" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\$' | sort -V | tail -1)
if [ -z "\$bin" ] || [ ! -f "\$VERSIONS_DIR/\$bin" ]; then
  echo "[claude] no installed binary in \$VERSIONS_DIR. Re-run install.sh" >&2
  exit 1
fi
bin="\$VERSIONS_DIR/\$bin"

# Self-heal: re-patch if anything outside our control swapped the binary
interp=\$(LD_PRELOAD= "\$PATCHELF" --print-interpreter "\$bin" 2>/dev/null || echo unknown)
if [ "\$interp" != "\$GLIBC_LD" ]; then
  echo "[claude] re-patching ELF interpreter (was: \$interp)" >&2
  LD_PRELOAD= "\$PATCHELF" --set-interpreter "\$GLIBC_LD" "\$bin" \
    || { echo "[claude] patchelf failed; cannot run \$bin" >&2; exit 1; }
fi

unset LD_PRELOAD
exec "\$bin" "\${args[@]}"
EOF
chmod +x "$WRAPPER"
ok "wrapper installed at $WRAPPER"

# --- Native-install launcher discovery ---
# Claude Code sees the binary under ~/.local/share/claude/versions, treats it as
# a native install, and expects a launcher at ~/.local/bin/claude with
# ~/.local/bin on PATH. Without them it prints "Native installation ... not in
# your PATH" notices at startup. Set both up the way claude's own message
# prescribes. The launcher points at this wrapper so every invocation still
# routes through it; ~/.local/bin is appended to PATH so $PREFIX/bin stays first.
mkdir -p "$HOME/.local/bin"
ln -sfn "$WRAPPER" "$HOME/.local/bin/claude"
if ! grep -Fq 'native-install launcher discovery' "$HOME/.bashrc" 2>/dev/null; then
  printf '\n# claude-code-android: native-install launcher discovery\nexport PATH="$PATH:$HOME/.local/bin"\n' >> "$HOME/.bashrc"
  ok "added ~/.local/bin to PATH in ~/.bashrc"
else
  ok "PATH already includes ~/.local/bin in ~/.bashrc"
fi

# --- Recommended packages (Q2) ---
if [ "$RECOMMENDED" = 1 ]; then
  info "installing recommended packages (this is the longest step)"
  pkg install $PKG_OPTS git gh wget jq python openssh tree proot \
    termux-api proot-distro make clang file xxd htop bat fzf >/dev/null \
    || fail "recommended package install failed"
  ok "recommended packages installed"
fi

# --- Verify ---
hash -r 2>/dev/null || true
VER="$(claude --version 2>&1)" || fail "claude --version failed: $VER"
ok "claude --version: $VER"

# --- Done ---
cat <<DONE

Install complete.

  Wrapper:   $WRAPPER
  Binary:    $BINARY
  Settings:  $HOME/.claude/settings.json

The wrapper auto-checks for a new claude release once per day on launch.
To force an immediate check at any time:  claude --update-now

Open a new Termux session (so the updated PATH is active and startup is
warning-free), then type:

  claude

DONE
