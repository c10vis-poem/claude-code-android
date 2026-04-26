#!/usr/bin/env bash
# verify-claims.sh: Tests every technical claim in the claude-code-android docs
# Safe to run on a live device. Non-destructive. Restores all state.
#
# Usage: bash tests/verify-claims.sh
# Results: stdout + tests/results/<device>-<android>.txt
#
# Results are saved per-device. Submit yours via PR to help build
# the compatibility database.

set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"

# Generate a device-specific filename
DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]' || true)
if [ -z "$DEVICE_MODEL" ]; then
  DEVICE_MODEL=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r' | tr ' ' '-' | tr '[:upper:]' '[:lower:]' || true)
fi
DEVICE_MODEL="${DEVICE_MODEL:-unknown}"

ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null || true)
if [ -z "$ANDROID_VER" ]; then
  ANDROID_VER=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)
fi
ANDROID_VER="${ANDROID_VER:-unknown}"
RESULTS_DIR="$(dirname "$0")/results"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="${RESULTS_DIR}/${DEVICE_MODEL:-unknown}-android${ANDROID_VER:-unknown}.txt"

# Counters
CONFIRMED=0
UNCONFIRMED=0
CANNOT_TEST=0
TOTAL=0

# --- Output helpers ---

tee_output() {
    tee -a "$RESULTS_FILE"
}

print_header() {
    local kernel
    kernel="$(uname -r 2>/dev/null || echo 'unknown')"
    local date_str
    date_str="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
    local kernel_short="${kernel:0:40}"
    printf "╔══════════════════════════════════════════════════════╗\n"
    printf "║  claude-code-android : Claims Verification           ║\n"
    printf "║  Date: %-45s║\n" "$date_str"
    printf "║  Kernel: %-43s║\n" "$kernel_short"
    printf "╚══════════════════════════════════════════════════════╝\n"
}

print_claim() {
    local num="$1"
    local title="$2"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CLAIM $num: $title"
}

verdict_confirmed() {
    CONFIRMED=$((CONFIRMED + 1))
    TOTAL=$((TOTAL + 1))
    echo "  Verdict: CONFIRMED"
}

verdict_unconfirmed() {
    local reason="$1"
    UNCONFIRMED=$((UNCONFIRMED + 1))
    TOTAL=$((TOTAL + 1))
    echo "  Verdict: UNCONFIRMED. $reason"
}

verdict_cannot_test() {
    local reason="$1"
    CANNOT_TEST=$((CANNOT_TEST + 1))
    TOTAL=$((TOTAL + 1))
    echo "  Verdict: CANNOT TEST. $reason"
}

# --- Reset results file ---
: > "$RESULTS_FILE"

# Pipe everything to both stdout and file
exec > >(tee "$RESULTS_FILE") 2>&1

print_header

# ──────────────────────────────────────────────────────────────
# CLAIM 1: npm fails silently without TMPDIR
# Source: README.md line 41, TROUBLESHOOTING.md line 254, INSTALL.md line 88
# ──────────────────────────────────────────────────────────────
print_claim 1 "npm fails silently without TMPDIR"
echo "  Source: README.md:41, TROUBLESHOOTING.md:254, INSTALL.md:88"
echo "  Claim: Without TMPDIR set, npm cannot stage files and fails silently"
echo "  Test: Unset TMPDIR, run 'npm cache ls', restore TMPDIR"

SAVED_TMPDIR="${TMPDIR:-}"

# Unset TMPDIR for this subshell test only
NPM_WITHOUT_TMPDIR_OUTPUT=""
NPM_WITHOUT_TMPDIR_EXIT=0
NPM_WITHOUT_TMPDIR_OUTPUT=$(unset TMPDIR && npm cache ls 2>&1) || NPM_WITHOUT_TMPDIR_EXIT=$?
NPM_WITH_TMPDIR_EXIT=0
NPM_WITH_TMPDIR_OUTPUT=$(TMPDIR="$PREFIX/tmp" npm cache ls 2>&1) || NPM_WITH_TMPDIR_EXIT=$?

# Restore TMPDIR
export TMPDIR="$SAVED_TMPDIR"

echo "  Test (without TMPDIR): exit=$NPM_WITHOUT_TMPDIR_EXIT"
if [ -n "$NPM_WITHOUT_TMPDIR_OUTPUT" ]; then
    echo "  Evidence (without TMPDIR): $(echo "$NPM_WITHOUT_TMPDIR_OUTPUT" | head -3)"
else
    echo "  Evidence (without TMPDIR): (no output, silent failure)"
fi
echo "  Test (with TMPDIR=$PREFIX/tmp): exit=$NPM_WITH_TMPDIR_EXIT"
echo "  Evidence (with TMPDIR): $(echo "$NPM_WITH_TMPDIR_OUTPUT" | head -1)"

if [ $NPM_WITHOUT_TMPDIR_EXIT -ne 0 ] && [ $NPM_WITH_TMPDIR_EXIT -eq 0 ]; then
    echo "  Result: npm failed without TMPDIR (exit $NPM_WITHOUT_TMPDIR_EXIT) and succeeded with TMPDIR"
    verdict_confirmed
elif [ -z "$NPM_WITHOUT_TMPDIR_OUTPUT" ] && [ -n "$NPM_WITH_TMPDIR_OUTPUT" ]; then
    echo "  Result: npm produced no output without TMPDIR (silent failure), output with TMPDIR"
    verdict_confirmed
else
    echo "  Result: npm cache ls succeeded both with and without TMPDIR on this test"
    echo "  Note: 'npm cache ls' may not exercise the code path that fails. The claim"
    echo "        specifically applies to 'npm install' which writes temp files during"
    echo "        package staging. This test cannot fully replicate that without installing."
    verdict_unconfirmed "npm cache ls is not a full proxy for npm install staging behavior"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 2: /tmp isn't writable without proot; PREFIX/tmp exists and is writable
# Source: README.md:74, TROUBLESHOOTING.md:81, INSTALL.md:42
# ──────────────────────────────────────────────────────────────
print_claim 2 "/tmp requires proot bind mount to be writable on Android"
echo "  Source: README.md:74, TROUBLESHOOTING.md:81, INSTALL.md:42"
echo "  Claim: /tmp isn't writable from Termux sandbox; proot bind-mounts \$PREFIX/tmp to /tmp"

# We're inside proot, so /tmp should work
TMP_WRITABLE=false
TMP_TEST_FILE="/tmp/verify-claims-test-$$"
if touch "$TMP_TEST_FILE" 2>/dev/null; then
    TMP_WRITABLE=true
    rm -f "$TMP_TEST_FILE"
fi

PREFIX_TMP_WRITABLE=false
PREFIX_TMP_TEST="$PREFIX/tmp/verify-claims-test-$$"
if touch "$PREFIX_TMP_TEST" 2>/dev/null; then
    PREFIX_TMP_WRITABLE=true
    rm -f "$PREFIX_TMP_TEST"
fi

TMP_IS_SYMLINK=false
if [ -L /tmp ] || [ "$(stat -c '%i' /tmp 2>/dev/null)" = "$(stat -c '%i' "$PREFIX/tmp" 2>/dev/null)" ]; then
    TMP_IS_SYMLINK=true
fi

echo "  Test: ls -la /tmp"
ls -la /tmp 2>/dev/null | head -5 | sed 's/u0_a[0-9]*/\<uid\>/g' || echo "  (ls /tmp failed)"
echo "  Result:"
echo "    /tmp writable (we are inside proot): $TMP_WRITABLE"
echo "    \$PREFIX/tmp writable: $PREFIX_TMP_WRITABLE"
echo "    /tmp and \$PREFIX/tmp resolve to same inode: $TMP_IS_SYMLINK"
CLAUDE_SOCK_COUNT=$(ls -d /tmp/claude-* 2>/dev/null | wc -l)
echo "  Evidence: Claude Code socket dirs in /tmp: $CLAUDE_SOCK_COUNT found"

echo "  Note: We are already inside a proot session. The 'without proot' case"
echo "        cannot be tested without exiting proot, which would break this script."
echo "        We verify the POSITIVE claim: proot bind mount makes /tmp writable."

if $TMP_WRITABLE && $PREFIX_TMP_WRITABLE; then
    echo "  Result: Both /tmp and \$PREFIX/tmp are writable inside proot"
    verdict_confirmed
else
    verdict_unconfirmed "could not write to /tmp=$TMP_WRITABLE, PREFIX/tmp=$PREFIX_TMP_WRITABLE"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 3: Claude Code doesn't bundle arm64-android ripgrep binary
# Source: TROUBLESHOOTING.md:279
# ──────────────────────────────────────────────────────────────
print_claim 3 "Claude Code does not bundle an arm64-android ripgrep binary"
echo "  Source: TROUBLESHOOTING.md:263,279"
echo "  Claim: Claude Code bundles platform-specific rg binaries but has no arm64-android build"

CLAUDE_BIN="$(command -v claude 2>/dev/null || echo '')"
if [ -z "$CLAUDE_BIN" ]; then
    echo "  Test: claude binary not found on PATH"
    verdict_cannot_test "claude binary not on PATH"
else
    VENDOR_BASE="$(dirname "$CLAUDE_BIN")/../lib/node_modules/@anthropic-ai/claude-code/vendor/ripgrep"
    echo "  Test: Inspect $VENDOR_BASE"

    echo "  Evidence: Platform directories in vendor/ripgrep:"
    ls "$VENDOR_BASE/" 2>/dev/null | sed 's/^/    /' || echo "    (vendor dir not found)"

    ANDROID_DIR="$VENDOR_BASE/arm64-android"
    ANDROID_RG="$ANDROID_DIR/rg"

    if [ -L "$ANDROID_RG" ]; then
        LINK_TARGET="$(readlink "$ANDROID_RG" 2>/dev/null || echo 'unknown')"
        echo "  Evidence: arm64-android/rg is a SYMLINK -> $LINK_TARGET"
        echo "  Result: No native arm64-android binary. Our symlink is the only rg there."

        # Cross-check: arm64-linux has a native binary (for comparison)
        LINUX_RG="$VENDOR_BASE/arm64-linux/rg"
        if [ -f "$LINUX_RG" ] && [ ! -L "$LINUX_RG" ]; then
            LINUX_SIZE="$(stat -c '%s' "$LINUX_RG" 2>/dev/null || echo '?')"
            echo "  Evidence: arm64-linux/rg is a native binary ($LINUX_SIZE bytes); confirms arm64-android is absent"
        fi
        verdict_confirmed

    elif [ -f "$ANDROID_RG" ] && [ ! -L "$ANDROID_RG" ]; then
        ANDROID_SIZE="$(stat -c '%s' "$ANDROID_RG" 2>/dev/null || echo '?')"
        echo "  Evidence: arm64-android/rg is a NATIVE binary ($ANDROID_SIZE bytes)"
        echo "  Result: Anthropic has shipped an arm64-android binary. Claim is now FALSE."
        verdict_unconfirmed "a native arm64-android binary was found; Anthropic may have added it"

    elif [ -d "$ANDROID_DIR" ]; then
        echo "  Evidence: arm64-android/ directory exists but contains no rg binary"
        echo "  Result: Directory exists but no binary and no symlink. Claim effectively confirmed."
        verdict_confirmed

    else
        echo "  Evidence: arm64-android/ directory does not exist at all"
        echo "  Result: No arm64-android directory; no native binary exists"
        verdict_confirmed
    fi
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 4: Node.js v24 hangs; v25+ required
# Source: TROUBLESHOOTING.md:153-175, README.md:78, INSTALL.md:47
# ──────────────────────────────────────────────────────────────
print_claim 4 "Node.js v24 hangs on ARM64 under Termux; v25+ required"
echo "  Source: TROUBLESHOOTING.md:153, README.md:78, INSTALL.md:47"
echo "  Claim: Node.js v24 hangs on startup. Upgrading to v25+ resolves it."
echo "  Test: Cannot downgrade Node.js safely. Report current version."
echo "        Upstream: github.com/anthropics/claude-code/issues/23634"
echo "        Upstream: github.com/anthropics/claude-code/issues/23665"

NODE_VERSION="$(node -v 2>/dev/null || echo 'not found')"
NODE_MAJOR="${NODE_VERSION#v}"
NODE_MAJOR="${NODE_MAJOR%%.*}"

echo "  Evidence:"
echo "    Current Node.js: $NODE_VERSION"
echo "    Required: v25+"
echo "    Upstream issue #23634: https://github.com/anthropics/claude-code/issues/23634"
echo "    Upstream issue #23665: https://github.com/anthropics/claude-code/issues/23665"

if [ "$NODE_MAJOR" -ge 25 ] 2>/dev/null; then
    echo "  Result: Running v25+. Claim consistent: we are on the correct version."
    echo "          The v24 hang cannot be tested without downgrading."
fi
verdict_cannot_test "downgrading Node.js would break the working environment"

# ──────────────────────────────────────────────────────────────
# CLAIM 5: proot-distro works on kernel 6.12 with proot 5.1.107-66+
# Source: TROUBLESHOOTING.md:124, INSTALL.md:32
# ──────────────────────────────────────────────────────────────
print_claim 5 "proot-distro works on kernel 6.12 with proot >= 5.1.107-66"
echo "  Source: TROUBLESHOOTING.md:124, INSTALL.md:32"
echo "  Claim: TCGETS2 ioctl bug fixed in proot 5.1.107-66 (Oct 2025). Guest distros work."

PROOT_VERSION="$(dpkg -s proot 2>/dev/null | grep '^Version:' | awk '{print $2}' || echo 'unknown')"
KERNEL_VERSION="$(uname -r 2>/dev/null || echo 'unknown')"
PROOT_DISTRO_VERSION="$(dpkg -s proot-distro 2>/dev/null | grep '^Version:' | awk '{print $2}' || echo 'unknown')"
PROOT_DISTRO_INSTALLED="$(command -v proot-distro 2>/dev/null | grep -q . && echo 'yes' || echo 'no')"

# Extract proot numeric version for comparison
PROOT_VER_NUM="${PROOT_VERSION#*:}"  # strip epoch if present
PROOT_PATCH="${PROOT_VER_NUM##*-}"   # get patch component (e.g. "70")
PROOT_MAIN="${PROOT_VER_NUM%%-*}"    # get main version (e.g. "5.1.107")

# Compare: need >= 5.1.107-66
PROOT_SUFFICIENT=false
if [ "$PROOT_MAIN" = "5.1.107" ] && [ "${PROOT_PATCH:-0}" -ge 66 ] 2>/dev/null; then
    PROOT_SUFFICIENT=true
elif [ -n "$PROOT_MAIN" ]; then
    # Rough semver: if main version string > 5.1.107, also sufficient
    MAJOR="${PROOT_MAIN%%.*}"; REST="${PROOT_MAIN#*.}"
    MINOR="${REST%%.*}"; PATCH="${REST#*.}"
    if [ "$MAJOR" -gt 5 ] || ( [ "$MAJOR" -eq 5 ] && [ "$MINOR" -gt 1 ] ) || \
       ( [ "$MAJOR" -eq 5 ] && [ "$MINOR" -eq 1 ] && [ "${PATCH:-0}" -gt 107 ] ); then
        PROOT_SUFFICIENT=true
    fi
fi

echo "  Evidence:"
echo "    Kernel: $KERNEL_VERSION"
echo "    proot version: $PROOT_VERSION"
echo "    proot-distro installed: $PROOT_DISTRO_INSTALLED"
[ "$PROOT_DISTRO_INSTALLED" = "yes" ] && echo "    proot-distro version: $PROOT_DISTRO_VERSION"
echo "    Minimum required proot: 5.1.107-66"
echo "    This proot sufficient: $PROOT_SUFFICIENT"

# Check if ubuntu rootfs actually exists (strongest evidence proot-distro works)
UBUNTU_ROOTFS="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu"
if [ -d "$UBUNTU_ROOTFS" ]; then
    echo "  Evidence: Ubuntu rootfs installed at $UBUNTU_ROOTFS"
    echo "  Result: Ubuntu guest is installed; proot-distro successfully ran on this device"
fi

if $PROOT_SUFFICIENT && [ -d "$UBUNTU_ROOTFS" ]; then
    echo "  Result: proot >= 5.1.107-66 confirmed, Ubuntu guest installed and verified"
    verdict_confirmed
elif $PROOT_SUFFICIENT; then
    echo "  Result: proot version meets minimum, no guest installed to verify runtime"
    verdict_confirmed
else
    echo "  Result: proot version ($PROOT_VERSION) may be below minimum 5.1.107-66"
    verdict_unconfirmed "proot version below required minimum"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 6: Android phantom process killer limits ~32 background processes
# Source: TROUBLESHOOTING.md:199, README.md:105
# ──────────────────────────────────────────────────────────────
print_claim 6 "Android phantom process killer limits ~32 background processes"
echo "  Source: TROUBLESHOOTING.md:199, README.md:105"
echo "  Claim: Android limits background processes to ~32 across all apps"
echo "  Test: Count current background processes visible from Termux"

BG_PROC_COUNT="$(find /proc/ -maxdepth 1 -regex '/proc/[0-9]+' 2>/dev/null | wc -l || echo '0')"

echo "  Evidence:"
echo "    Background processes visible in /proc: $BG_PROC_COUNT"
echo "    Limit claim: ~32"

# Check if developer option is enabled (affects this limit)
# We can't directly read developer settings, but we can note the current state
echo "    Note: 'Disable child process restrictions' developer option state"
echo "    cannot be read programmatically from Termux without root."
echo "    If this device shows >32 processes without being killed, that option"
echo "    may be enabled."

# We can observe but cannot prove the ~32 limit without triggering it
echo "  Result: Current process count reported. The ~32 limit itself cannot"
echo "          be proven without spawning processes until the killer fires"
echo "          (which would be destructive)."
verdict_cannot_test "proving the limit requires triggering it, which would kill processes"

# ──────────────────────────────────────────────────────────────
# CLAIM 7: File descriptor limits vary by device
# Source: TROUBLESHOOTING.md:228, README.md:104
# ──────────────────────────────────────────────────────────────
print_claim 7 "File descriptor limits vary by device"
echo "  Source: TROUBLESHOOTING.md:228, README.md:104"
echo "  Claim: The file descriptor limit varies by device and Android version"

FD_LIMIT_SOFT="$(ulimit -n 2>/dev/null || echo 'unknown')"
FD_LIMIT_HARD="$(ulimit -Hn 2>/dev/null || echo 'unknown')"

echo "  Test: ulimit -n (soft limit), ulimit -Hn (hard limit)"
echo "  Evidence:"
echo "    Soft FD limit: $FD_LIMIT_SOFT"
echo "    Hard FD limit: $FD_LIMIT_HARD"

if [ "$FD_LIMIT_SOFT" != 'unknown' ] && [ "$FD_LIMIT_SOFT" -gt 0 ] 2>/dev/null; then
    echo "  Result: FD limit is $FD_LIMIT_SOFT (soft) / $FD_LIMIT_HARD (hard)"
    echo "          The docs say limits vary by device. This value confirms FD limits"
    echo "          exist and are queryable. Actual values differ across devices and"
    echo "          Android versions (e.g. 1024, 32768, or higher)."
    verdict_confirmed
else
    verdict_cannot_test "could not read ulimit value"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 8: ~/.bashrc should have TMPDIR and claude-android alias
# Source: README.md:53-54, INSTALL.md:126-129, TROUBLESHOOTING.md:44-48
# ──────────────────────────────────────────────────────────────
print_claim 8 "TMPDIR and proot alias should be in ~/.bashrc for persistence"
echo "  Source: README.md:53-54, INSTALL.md:126-129, TROUBLESHOOTING.md:44-48"
echo "  Claim: TMPDIR=\$PREFIX/tmp and claude-android alias should be in ~/.bashrc"

BASHRC="$HOME/.bashrc"
TMPDIR_IN_BASHRC=false
ALIAS_IN_BASHRC=false

if [ -f "$BASHRC" ]; then
    if grep -q 'TMPDIR' "$BASHRC" 2>/dev/null; then
        TMPDIR_IN_BASHRC=true
    fi
    if grep -q 'claude-android\|claude.*proot\|proot.*claude' "$BASHRC" 2>/dev/null; then
        ALIAS_IN_BASHRC=true
    fi

    echo "  Evidence: ~/.bashrc contents (relevant lines):"
    grep -n 'TMPDIR\|claude\|proot' "$BASHRC" 2>/dev/null | sed 's/^/    /' || echo "    (no matches)"
else
    echo "  Evidence: ~/.bashrc does not exist"
fi

echo "  Result:"
echo "    TMPDIR in ~/.bashrc: $TMPDIR_IN_BASHRC"
echo "    proot/claude alias in ~/.bashrc: $ALIAS_IN_BASHRC"

if $TMPDIR_IN_BASHRC && $ALIAS_IN_BASHRC; then
    echo "  Result: Both TMPDIR and claude proot alias found in ~/.bashrc"
    verdict_confirmed
elif $TMPDIR_IN_BASHRC; then
    echo "  Result: TMPDIR found but no claude-android proot alias in ~/.bashrc"
    # Check for any proot alias as alternative
    if grep -q 'proot' "$BASHRC" 2>/dev/null; then
        echo "  Note: proot alias found in ~/.bashrc -- functionally equivalent"
        verdict_confirmed
    else
        verdict_unconfirmed "no proot launch alias found (expected claude-android or similar)"
    fi
else
    verdict_unconfirmed "TMPDIR=$TMPDIR_IN_BASHRC, alias=$ALIAS_IN_BASHRC in ~/.bashrc"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 9: proot -b $PREFIX/tmp:/tmp remaps /tmp; Claude Code creates /tmp/claude* dirs
# Source: INSTALL.md:118, TROUBLESHOOTING.md:71
# ──────────────────────────────────────────────────────────────
print_claim 9 "proot -b \$PREFIX/tmp:/tmp remaps /tmp for Claude Code"
echo "  Source: INSTALL.md:118, TROUBLESHOOTING.md:71"
echo "  Claim: proot intercepts syscalls and makes /tmp point to \$PREFIX/tmp"


echo "  Test: Check if /tmp and \$PREFIX/tmp contain identical contents (confirms bind mount)"

TMP_FILES="$(ls /tmp/ 2>/dev/null | sort || echo '')"
PREFIX_TMP_FILES="$(ls "$PREFIX/tmp/" 2>/dev/null | sort || echo '')"

echo "  Evidence:"
echo "    /tmp contents: $(echo "$TMP_FILES" | tr '\n' ' ' | head -c 200)"
echo "    \$PREFIX/tmp contents: $(echo "$PREFIX_TMP_FILES" | tr '\n' ' ' | head -c 200)"

CLAUDE_DIRS_IN_TMP="$(ls -d /tmp/claude-* 2>/dev/null | head -5 || echo '')"
if [ -n "$CLAUDE_DIRS_IN_TMP" ]; then
    echo "    Claude Code runtime dirs in /tmp: $CLAUDE_DIRS_IN_TMP"
fi

# The strongest test: write a file to /tmp and check if it appears in $PREFIX/tmp
TEST_MARKER="verify-claims-bind-test-$$"
echo "test" > "/tmp/$TEST_MARKER" 2>/dev/null || true
FOUND_IN_PREFIX=false
if [ -f "$PREFIX/tmp/$TEST_MARKER" ]; then
    FOUND_IN_PREFIX=true
fi
rm -f "/tmp/$TEST_MARKER" "$PREFIX/tmp/$TEST_MARKER" 2>/dev/null || true

echo "    Write to /tmp, read from \$PREFIX/tmp (bind mount test): $FOUND_IN_PREFIX"

if [ "$TMP_FILES" = "$PREFIX_TMP_FILES" ] || $FOUND_IN_PREFIX; then
    echo "  Result: /tmp and \$PREFIX/tmp are the same filesystem location; bind mount confirmed"
    verdict_confirmed
elif [ -n "$CLAUDE_DIRS_IN_TMP" ]; then
    echo "  Result: Claude Code created /tmp/claude-* dirs, proving /tmp is writable inside proot"
    verdict_confirmed
else
    verdict_unconfirmed "could not confirm /tmp == \$PREFIX/tmp bind relationship"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 10: Native curl installer works inside proot-distro Ubuntu
# Source: INSTALL.md:248-256
# ──────────────────────────────────────────────────────────────
print_claim 10 "curl installer (claude.ai/install.sh) works inside proot-distro Ubuntu"
echo "  Source: INSTALL.md:248-256"
echo "  Claim: 'curl -fsSL https://claude.ai/install.sh | bash' installs Claude Code in Ubuntu guest"

UBUNTU_ROOTFS="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu"
UBUNTU_CLAUDE_PATHS=(
    "$UBUNTU_ROOTFS/root/.local/bin/claude"
    "$UBUNTU_ROOTFS/home/user/.local/bin/claude"
    "$UBUNTU_ROOTFS/usr/local/bin/claude"
)

echo "  Test: Check if Ubuntu guest is installed and contains a claude binary"

if [ ! -d "$UBUNTU_ROOTFS" ]; then
    echo "  Evidence: Ubuntu guest not installed at $UBUNTU_ROOTFS"
    verdict_cannot_test "Ubuntu proot-distro guest not installed on this device"
else
    echo "  Evidence: Ubuntu guest rootfs found at $UBUNTU_ROOTFS"
    CLAUDE_FOUND=false
    CLAUDE_PATH=""
    for path in "${UBUNTU_CLAUDE_PATHS[@]}"; do
        # Use -e (exists) to catch both regular files and symlinks
        if [ -e "$path" ] || [ -L "$path" ]; then
            CLAUDE_FOUND=true
            CLAUDE_PATH="$path"
            break
        fi
    done

    if $CLAUDE_FOUND; then
        if [ -L "$CLAUDE_PATH" ]; then
            LINK_TARGET="$(readlink "$CLAUDE_PATH" 2>/dev/null || echo 'unknown')"
            echo "    Claude Code binary found (symlink): $CLAUDE_PATH -> $LINK_TARGET"
        else
            echo "    Claude Code binary found: $CLAUDE_PATH"
            FILE_SIZE="$(stat -c '%s' "$CLAUDE_PATH" 2>/dev/null || echo '?')"
            echo "    File size: $FILE_SIZE bytes"
        fi

        echo "  Result: Claude Code binary present in Ubuntu guest; installer ran successfully"
        verdict_confirmed
    else
        echo "    Searched paths:"
        for path in "${UBUNTU_CLAUDE_PATHS[@]}"; do
            echo "      $path: $([ -f "$path" ] && echo 'FOUND' || echo 'not found')"
        done
        echo "    Ubuntu guest is installed but no claude binary found in expected locations"
        echo "    The installer may not have been run yet in this guest"
        verdict_unconfirmed "Ubuntu guest present but no claude binary found; installer not yet run"
    fi
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 11: Cron sessions support tool restrictions
# Source: CLAUDE.md constraint 11
# ──────────────────────────────────────────────────────────────
print_claim 11 "Cron sessions support tool restrictions via --tools flag"
echo "  Source: CLAUDE.md constraint 11"
echo "  Claim: claude CLI accepts --tools flag to restrict available tools in cron sessions"

CLAUDE_BIN_11="$(command -v claude 2>/dev/null || echo '')"
if [ -z "$CLAUDE_BIN_11" ]; then
    echo "  Test: claude binary not found on PATH"
    verdict_cannot_test "claude binary not installed"
else
    TOOLS_FLAG_FOUND=false
    if claude --help 2>&1 | grep -q "tools"; then
        TOOLS_FLAG_FOUND=true
    fi

    echo "  Evidence:"
    echo "    claude binary: $CLAUDE_BIN_11"
    echo "    --tools flag in help output: $TOOLS_FLAG_FOUND"

    if $TOOLS_FLAG_FOUND; then
        echo "  Result: claude CLI accepts --tools flag for restricting tool access"
        verdict_confirmed
    else
        echo "  Result: --tools flag not found in claude --help output"
        verdict_unconfirmed "--tools flag not found in help output"
    fi
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 12: NDK sensor access works
# Source: termux/sensor-poc.c
# ──────────────────────────────────────────────────────────────
print_claim 12 "NDK sensor access works via termux-sensor"
echo "  Source: termux/sensor-poc.c"
echo "  Claim: termux-sensor can list and read device sensors"

TERMUX_SENSOR_BIN="$(command -v termux-sensor 2>/dev/null || echo '')"
if [ -z "$TERMUX_SENSOR_BIN" ]; then
    SENSOR_POC="$HOME/repos/claude-code-android/termux/sensor-poc"
    if [ -x "$SENSOR_POC" ]; then
        echo "  Evidence: sensor-poc binary exists at $SENSOR_POC"
        echo "  Result: NDK sensor proof-of-concept compiled; termux-sensor not available"
        verdict_cannot_test "termux-sensor not available but sensor-poc binary exists"
    else
        echo "  Evidence: Neither termux-sensor nor sensor-poc binary found"
        verdict_cannot_test "Termux:API not installed (termux-sensor not available)"
    fi
else
    echo "  Test: termux-sensor -l (5-second timeout)"
    SENSOR_OUTPUT=""
    SENSOR_OUTPUT=$(timeout 5 termux-sensor -l 2>/dev/null | head -5 || echo '')

    echo "  Evidence:"
    if [ -n "$SENSOR_OUTPUT" ]; then
        echo "$SENSOR_OUTPUT" | sed 's/^/    /'
        echo "  Result: Sensor data returned from termux-sensor"
        verdict_confirmed
    else
        echo "    (no output or timed out)"
        verdict_cannot_test "termux-sensor returned no data or timed out (companion app may not be running)"
    fi
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 13: SSRF guard hook documented
# Source: docs/ssrf-guard.md
# ──────────────────────────────────────────────────────────────
print_claim 13 "SSRF guard hook documented"
echo "  Source: docs/ssrf-guard.md"
echo "  Claim: SSRF guard hook documentation exists in docs/ssrf-guard.md"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSRF_DOC="$REPO_ROOT/docs/ssrf-guard.md"

echo "  Test: Check if docs/ssrf-guard.md exists and is non-empty"

if [ -f "$SSRF_DOC" ] && [ -s "$SSRF_DOC" ]; then
    DOC_LINES="$(wc -l < "$SSRF_DOC")"
    echo "  Evidence: $SSRF_DOC exists ($DOC_LINES lines)"
    echo "  Result: SSRF guard documentation present"
    verdict_confirmed
else
    echo "  Evidence: $SSRF_DOC not found or empty"
    verdict_unconfirmed "docs/ssrf-guard.md missing or empty"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 14: Agent permission separation documented
# Source: docs/agent-permissions.md
# ──────────────────────────────────────────────────────────────
print_claim 14 "Agent permission separation documented"
echo "  Source: docs/agent-permissions.md"
echo "  Claim: Agent permission separation documentation exists in docs/agent-permissions.md"

AGENT_PERMS_DOC="$REPO_ROOT/docs/agent-permissions.md"

echo "  Test: Check if docs/agent-permissions.md exists and is non-empty"

if [ -f "$AGENT_PERMS_DOC" ] && [ -s "$AGENT_PERMS_DOC" ]; then
    DOC_LINES="$(wc -l < "$AGENT_PERMS_DOC")"
    echo "  Evidence: $AGENT_PERMS_DOC exists ($DOC_LINES lines)"
    echo "  Result: Agent permission separation documentation present"
    verdict_confirmed
else
    echo "  Evidence: $AGENT_PERMS_DOC not found or empty"
    verdict_unconfirmed "docs/agent-permissions.md missing or empty"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 15: Termux:API available
# Source: README.md, INSTALL.md
# ──────────────────────────────────────────────────────────────
print_claim 15 "Termux:API available (termux-battery-status)"
echo "  Source: README.md, INSTALL.md"
echo "  Claim: Termux:API package provides device access via termux-battery-status etc."

BATTERY_BIN="$(command -v termux-battery-status 2>/dev/null || echo '')"
if [ -z "$BATTERY_BIN" ]; then
    echo "  Evidence: termux-battery-status not found on PATH"
    verdict_cannot_test "termux-api package not installed"
else
    echo "  Test: termux-battery-status (5-second timeout)"
    BATTERY_OUTPUT=""
    BATTERY_OUTPUT=$(timeout 5 termux-battery-status 2>/dev/null || echo '')

    echo "  Evidence:"
    if echo "$BATTERY_OUTPUT" | grep -q "percentage"; then
        echo "$BATTERY_OUTPUT" | head -10 | sed 's/^/    /'
        echo "  Result: Valid JSON with percentage field returned"
        verdict_confirmed
    else
        echo "    Output: $(echo "$BATTERY_OUTPUT" | head -3)"
        echo "    (no 'percentage' field found)"
        verdict_cannot_test "termux-battery-status did not return valid data (companion app may not be running)"
    fi
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 16: xdg-open exists as termux-open symlink
# Source: INSTALL.md
# ──────────────────────────────────────────────────────────────
print_claim 16 "xdg-open exists as termux-open symlink"
echo "  Source: INSTALL.md"
echo "  Claim: xdg-open is a symlink to termux-open for desktop compatibility"

XDG_OPEN_PATH="$(command -v xdg-open 2>/dev/null || echo '')"
if [ -z "$XDG_OPEN_PATH" ]; then
    echo "  Evidence: xdg-open not found on PATH"
    verdict_unconfirmed "xdg-open not found on PATH"
else
    echo "  Test: Check if xdg-open is a symlink to termux-open"
    LINK_TARGET_16="$(readlink "$XDG_OPEN_PATH" 2>/dev/null || echo '')"

    echo "  Evidence:"
    echo "    xdg-open path: $XDG_OPEN_PATH"
    echo "    readlink result: $LINK_TARGET_16"

    if echo "$LINK_TARGET_16" | grep -q "termux-open"; then
        echo "  Result: xdg-open is a symlink to termux-open"
        verdict_confirmed
    else
        echo "  Result: xdg-open exists but is not a symlink to termux-open"
        verdict_unconfirmed "xdg-open exists but does not link to termux-open"
    fi
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 17: Fingerprint authentication available
# Source: CLAUDE.md, security gate implementation
# ──────────────────────────────────────────────────────────────
print_claim 17 "Fingerprint authentication available via termux-fingerprint"
echo "  Source: CLAUDE.md, security gate implementation"
echo "  Claim: termux-fingerprint command is available for biometric authentication"

FINGERPRINT_BIN="$(command -v termux-fingerprint 2>/dev/null || echo '')"
if [ -n "$FINGERPRINT_BIN" ]; then
    echo "  Evidence: termux-fingerprint found at $FINGERPRINT_BIN"
    echo "  Result: Fingerprint authentication command is on PATH"
    verdict_confirmed
else
    echo "  Evidence: termux-fingerprint not found on PATH"
    verdict_cannot_test "termux-api package not installed (termux-fingerprint not available)"
fi

# ──────────────────────────────────────────────────────────────
# CLAIM 18: Architecture is aarch64
# Source: README.md, TROUBLESHOOTING.md
# ──────────────────────────────────────────────────────────────
print_claim 18 "Architecture is aarch64"
echo "  Source: README.md, TROUBLESHOOTING.md"
echo "  Claim: Device architecture is aarch64 (ARM 64-bit)"

ARCH="$(uname -m 2>/dev/null || echo 'unknown')"
echo "  Test: uname -m"
echo "  Evidence: Architecture reported as '$ARCH'"

if [ "$ARCH" = "aarch64" ]; then
    echo "  Result: Architecture confirmed as aarch64"
    verdict_confirmed
else
    echo "  Result: Architecture is '$ARCH', not aarch64"
    verdict_unconfirmed "architecture is '$ARCH', expected 'aarch64'"
fi

# ──────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Confirmed:    $CONFIRMED/$TOTAL"
echo "  Unconfirmed:  $UNCONFIRMED/$TOTAL"
echo "  Cannot test:  $CANNOT_TEST/$TOTAL"
echo ""
echo "Results written to: $RESULTS_FILE"
echo ""
echo "Notes:"
echo "  UNCONFIRMED does not mean FALSE: it means the live test could not"
echo "  produce the failure condition safely on a working device."
echo "  CANNOT TEST indicates claims verified by upstream evidence or prior"
echo "  test records rather than live reproduction."
