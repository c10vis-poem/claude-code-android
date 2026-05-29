#!/data/data/com.termux/files/usr/bin/bash
# claude-code-android migration: pinned v2.x  ->  v2.9.0
#
# For existing users on the old pinned Path A install (npm package
# @anthropic-ai/claude-code, typically 2.1.112, locked read-only with the
# in-process auto-updater disabled). This moves you to the v2.9.0 architecture
# (patched native linux-arm64 binary + auto-updating wrapper) WITHOUT losing
# your work.
#
# Preserved untouched: your chats/sessions, OAuth login, settings.json,
# and any custom agents/hooks/skills/CLAUDE.md under ~/.claude.
#
# Safety:
#   - A full backup of ~/.claude, ~/.claude.json, and ~/.bashrc is taken
#     BEFORE anything destructive, with a restore.sh you can run to undo.
#   - The new binary is downloaded, checksum-verified, and patched BEFORE the
#     old install is removed, so a failure leaves your old install usable.
#   - Run this only when NO claude session is active.
#
# Fresh installs should use install.sh instead, not this script.
#
# SYNC NOTE: the npm-version resolve, download, checksum, patchelf, and the
# emitted wrapper below are kept byte-identical to install.sh. If you change
# one, change both.
#
# Tracking the upstream issue this works around:
#   https://github.com/anthropics/claude-code/issues/50270

set -euo pipefail

info(){ printf '\033[0;36m[info]\033[0m  %s\n' "$1"; }
ok(){   printf '\033[0;32m[ok]\033[0m    %s\n' "$1"; }
warn(){ printf '\033[0;33m[warn]\033[0m  %s\n' "$1" >&2; }
fail(){ printf '\033[0;31m[fail]\033[0m  %s\n' "$1" >&2; exit 1; }

BACKUP_DIR=""
on_err(){
  ec=$?
  printf '\033[0;31m[fail]\033[0m  migration stopped (exit %s).\n' "$ec" >&2
  if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    printf '        Your data backup is at: %s\n' "$BACKUP_DIR" >&2
    printf '        Restore it with:        bash %s/restore.sh\n' "$BACKUP_DIR" >&2
  fi
  exit "$ec"
}
trap on_err ERR

# --- Preflight ---
if [ -z "${PREFIX:-}" ]; then
  fail "PREFIX unset. Run this inside native Termux, not adb shell or proot."
fi
if [ "$PREFIX" != "/data/data/com.termux/files/usr" ]; then
  fail "This runs in native Termux only (PREFIX is $PREFIX). Path B/C installs do not need it."
fi
if [ "$(uname -m)" != "aarch64" ]; then
  fail "aarch64 only. uname -m reports: $(uname -m)"
fi
# Validate HOME before any path operation derives from it (DR-116 discipline:
# every destructive target must rest on a verified base path, never an assumption).
if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
  fail "HOME is unset or not a directory; refusing to run."
fi

# No live claude session: replacing the binary under a running session corrupts it.
RUNNING="$( { pgrep -x claude; pgrep -f '@anthropic-ai/claude-code'; } 2>/dev/null | sort -un | grep -vw "$$" | grep -vw "${PPID:-0}" | tr '\n' ' ' || true )"
if [ -n "${RUNNING// /}" ]; then
  fail "claude appears to be running (PIDs: $RUNNING). Close all claude sessions, then re-run."
fi

# A live proot session: the pkg-upgrade step can update proot packages under it.
if pgrep -x proot >/dev/null 2>&1; then
  warn "A proot session is running. The package-upgrade step can update proot packages underneath it."
  read -r -p "Continue anyway? [y/N] " PR
  case "${PR,,}" in
    y|yes) ;;
    *) fail "Aborted. Close the proot session and re-run." ;;
  esac
fi

cat <<'BANNER'

  claude-code-android migration  (pinned v2.x  ->  v2.9.0)
  =======================================================

BANNER

# --- Detect current install ---
NPM_PKG="$PREFIX/lib/node_modules/@anthropic-ai/claude-code"
BINLINK="$PREFIX/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"

state="foreign"
if [ -d "$VERSIONS_DIR" ] && ls "$VERSIONS_DIR"/*.*.* >/dev/null 2>&1 && [ -f "$BINLINK" ] && [ ! -L "$BINLINK" ]; then
  state="already_v29"
elif [ -d "$NPM_PKG" ]; then
  state="pinned"
elif [ -L "$BINLINK" ] && readlink "$BINLINK" | grep -q 'node_modules/@anthropic-ai/claude-code'; then
  state="pinned"
elif [ ! -e "$BINLINK" ] && [ ! -d "$NPM_PKG" ] && ! command -v claude >/dev/null 2>&1; then
  state="fresh"
fi

case "$state" in
  already_v29)
    ok "You are already on the v2.9.0 architecture (wrapper + versioned binary)."
    info "The wrapper auto-updates. Force a check with: claude --update-now"
    trap - ERR
    exit 0
    ;;
  fresh)
    fail "No existing claude install found. This is the upgrade path; for a fresh install run install.sh."
    ;;
  foreign)
    warn "Found a 'claude' this migrator did not install:"
    if [ -e "$BINLINK" ]; then ls -l "$BINLINK" >&2; fi
    if command -v claude >/dev/null 2>&1; then warn "claude resolves to: $(command -v claude)"; fi
    fail "Refusing to touch an install I did not create. Remove it yourself then run install.sh, or open an issue."
    ;;
esac

OLD_VER="$(claude --version 2>&1 | head -1 || echo unknown)"
ok "Detected pinned v2.x install (reports: $OLD_VER)."
echo

# --- Q: recommended packages ---
cat <<'Q'
Install recommended packages (git, gh, wget, jq, python, openssh, tree, proot,
termux-api, proot-distro, make, clang, file, xxd, htop, bat, fzf)? Already
installed ones are skipped. Choose no if you manage these yourself.
Q
read -r -p "Install recommended packages? [Y/n] " QR
QR="${QR:-Y}"
case "${QR,,}" in
  y|yes) RECOMMENDED=1 ;;
  n|no)  RECOMMENDED=0 ;;
  *) fail "answer 'y' or 'n'; got '$QR'" ;;
esac
echo

# --- Migration summary + explicit go ---
cat <<'SUMMARY'
This will:
  1. Back up ~/.claude, ~/.claude.json, and ~/.bashrc to a timestamped folder.
  2. Download, verify, and patch the latest claude linux-arm64 binary.
  3. Remove the old pinned v2.x install (the binary only).
  4. Install the auto-updating wrapper.
  5. Merge your settings.json, preserving your existing hooks/permissions/env.

Preserved untouched: your chats/sessions, login, agents, hooks, skills, CLAUDE.md.
SUMMARY
read -r -p "Proceed? [y/N] " GO
case "${GO,,}" in
  y|yes) ;;
  *) fail "Aborted by user. Nothing changed." ;;
esac
echo

# --- Backup (data first, before anything destructive) ---
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/claude-migration-backup-$STAMP"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
info "backing up to $BACKUP_DIR"
if [ -e "$HOME/.claude" ]; then
  # No -h: preserve symlinks as symlinks (e.g. config symlinked into a repo),
  # so a restore re-creates the links rather than duplicating their targets.
  tar czf "$BACKUP_DIR/dot-claude.tgz" -C "$HOME" .claude || fail "backup of ~/.claude failed"
fi
if [ -e "$HOME/.claude.json" ]; then cp -a "$HOME/.claude.json" "$BACKUP_DIR/"; fi
if [ -e "$HOME/.bashrc" ]; then cp -a "$HOME/.bashrc" "$BACKUP_DIR/"; fi
{
  echo "pre-version: $OLD_VER"
  echo "bin: $(ls -l "$BINLINK" 2>&1)"
  echo "node: $(node -v 2>&1 || echo none)"
  echo "date_utc: $STAMP"
} > "$BACKUP_DIR/pre-state.txt"

cat > "$BACKUP_DIR/restore.sh" <<'RESTORE'
#!/data/data/com.termux/files/usr/bin/bash
# Restore the data captured before the v2.9.0 migration.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
echo "Restoring ~/.claude, ~/.claude.json, ~/.bashrc from $here ..."
if [ -f "$here/dot-claude.tgz" ]; then
  # Verify the archive is readable BEFORE removing the live directory, so a
  # corrupt backup can never leave you with neither the old nor the backup.
  tar tzf "$here/dot-claude.tgz" >/dev/null 2>&1 || { echo "backup archive is unreadable; aborting restore to avoid data loss."; exit 1; }
  rm -rf "$HOME/.claude"
  tar xzf "$here/dot-claude.tgz" -C "$HOME"
fi
if [ -f "$here/.claude.json" ]; then cp -a "$here/.claude.json" "$HOME/.claude.json"; fi
if [ -f "$here/.bashrc" ]; then cp -a "$here/.bashrc" "$HOME/.bashrc"; fi
echo "Data restored. Your sessions and login are back regardless of which binary you run."
echo "To reinstall the old pinned binary (optional):"
echo "  npm install -g @anthropic-ai/claude-code@2.1.112"
RESTORE
chmod +x "$BACKUP_DIR/restore.sh"
ok "backup complete (restore: bash $BACKUP_DIR/restore.sh)"

# --- apt options: existing user, preserve their configs ---
export DEBIAN_FRONTEND=noninteractive
PKG_OPTS="-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

info "pkg update"
pkg update $PKG_OPTS >/dev/null || fail "pkg update failed"
info "pkg upgrade"
pkg upgrade $PKG_OPTS >/dev/null || fail "pkg upgrade failed"
info "pkg install curl jq"
pkg install $PKG_OPTS curl jq >/dev/null || fail "pkg install curl/jq failed"

info "pkg install glibc-repo"
pkg install $PKG_OPTS glibc-repo >/dev/null || fail "glibc-repo install failed"
pkg update $PKG_OPTS >/dev/null || fail "pkg update after glibc-repo failed"
info "pkg install glibc-runner patchelf-glibc (~50 MB)"
pkg install $PKG_OPTS glibc-runner patchelf-glibc >/dev/null || fail "glibc-runner install failed"

PATCHELF="$PREFIX/glibc/bin/patchelf"
GLIBC_LD="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
if [ ! -x "$PATCHELF" ]; then fail "patchelf not found at $PATCHELF"; fi
if [ ! -f "$GLIBC_LD" ]; then fail "glibc ld.so not found at $GLIBC_LD"; fi
ok "glibc-runner + patchelf ready"

# --- Resolve + stage the NEW binary (old install still intact at this point) ---
info "resolving latest claude version from npm registry"
LATEST="$(curl -fsSL --max-time 10 https://registry.npmjs.org/@anthropic-ai/claude-code/latest 2>/dev/null | jq -r .version 2>/dev/null)"
if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
  fail "could not query npm registry for the latest claude version"
fi
if ! printf '%s' "$LATEST" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  fail "npm registry returned an unexpected version string: $LATEST"
fi
ok "latest claude version: $LATEST"

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
  || { rm -f "$BINARY.tmp"; fail "patchelf failed to set ELF interpreter"; }
mv "$BINARY.tmp" "$BINARY"
ok "new binary staged at $BINARY"

# --- Remove the old pinned v2.x install (only now that the new binary is verified) ---
info "removing the old pinned v2.x install"
if [ -d "$NPM_PKG" ]; then chmod -R u+w "$NPM_PKG" 2>/dev/null || true; fi
if command -v npm >/dev/null 2>&1; then npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true; fi
if [ -d "$NPM_PKG" ]; then rm -rf "$NPM_PKG" 2>/dev/null || true; fi
if [ -L "$BINLINK" ]; then
  case "$(readlink "$BINLINK")" in
    *node_modules/@anthropic-ai/claude-code*) rm -f "$BINLINK" ;;
  esac
fi
ok "old install removed"

# --- Wrapper at $PREFIX/bin/claude  (KEEP BYTE-IDENTICAL TO install.sh) ---
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

# --- Merge settings.json (symlink-safe; preserve existing keys) ---
SF="$HOME/.claude/settings.json"
LP="$PREFIX/lib/libtermux-exec-ld-preload.so"
if [ -e "$SF" ]; then
  TMP="$(mktemp "${TMPDIR:-$PREFIX/tmp}/cc-settings.XXXXXX")"
  if jq --arg lp "$LP" '.autoUpdates=false | .env=((.env // {}) + {"LD_PRELOAD":$lp})' "$SF" > "$TMP" 2>/dev/null; then
    # Write THROUGH the file (cat, not mv) so a symlink is followed, not replaced.
    cat "$TMP" > "$SF"
    rm -f "$TMP"
    if [ -L "$SF" ]; then
      warn "settings.json is a symlink -> $(readlink -f "$SF"). Updated the target in place; if it is version-controlled, review and commit the change."
    fi
    ok "settings.json merged (your existing keys preserved)"
  else
    rm -f "$TMP"
    warn "settings.json is not valid JSON; leaving it untouched to avoid corrupting it."
    warn "Set  \"autoUpdates\": false  and  \"env\": { \"LD_PRELOAD\": \"$LP\" }  by hand."
  fi
else
  cat > "$SF" <<SET
{
  "autoUpdates": false,
  "env": {
    "LD_PRELOAD": "$LP"
  }
}
SET
  ok "settings.json written"
fi

# --- Recommended packages ---
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
RES="$(command -v claude || true)"
if [ "$RES" != "$WRAPPER" ]; then warn "claude resolves to $RES (expected $WRAPPER)"; fi
SESS="$(ls "$HOME/.claude/projects" 2>/dev/null | wc -l | tr -d ' ')"
ok "claude --version: $VER"

# --- bashrc stale-line detection (suggest only; never auto-edit) ---
STALE="$(grep -nE 'DISABLE_AUTOUPDATER=1|claude-android|CLAUDE_CODE_USE_NATIVE_FILE_SEARCH=1' "$HOME/.bashrc" 2>/dev/null || true)"

trap - ERR
cat <<DONE

Migration complete.

  Now on:    $VER
  Wrapper:   $WRAPPER
  Binary:    $BINARY
  Sessions:  $SESS preserved
  Backup:    $BACKUP_DIR
             (restore anytime with: bash $BACKUP_DIR/restore.sh)

Your login and chats are intact. The wrapper auto-checks for a new claude
release once per day on launch. Force a check with: claude --update-now

Open a new Termux session (so the updated PATH is active and startup is
warning-free), then type:

  claude

DONE

if [ -n "$STALE" ]; then
  cat <<NOTE
Optional cleanup: these old v2.x lines in ~/.bashrc are now harmless under
v2.9.0 and can be removed by hand if you like (leave anything else alone):
$STALE

NOTE
fi
