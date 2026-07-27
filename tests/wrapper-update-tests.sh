#!/usr/bin/env bash
# wrapper-update-tests.sh: regression tests for the self-updating launcher that
# install.sh (and, byte-identically, migrate.sh) write to $PREFIX/bin/claude.
#
# Why this exists: the launcher's once-a-day update check downloaded, verified,
# and swapped a new build through a SHARED, unlocked staging path
# ("$VERSIONS_DIR/$latest.tmp"). Two ordinary "claude" launches inside the
# up-to-5-minute download window therefore raced: one process's mv, or its
# retention-prune, unlinked the other's staging file, and the survivor printed a
# false "checksum mismatch" and stranded the update. Launching claude twice in a
# few minutes is normal use, so this stranded real users near a release.
#
# The suite GENERATES the actual wrapper from install.sh and drives it with
# stubbed curl / patchelf / timeout, so it exercises the SHIPPED control flow,
# not a reimplementation. It asserts the race is gone and that the self-heal
# tells a crash (blocklist) apart from an inconclusive probe (keep, never
# blocklist).
#
# Usage: bash tests/wrapper-update-tests.sh [path/to/install.sh]

set -u
INSTALL_SH="${1:-install.sh}"
[ -f "$INSTALL_SH" ] || { echo "install.sh not found: $INSTALL_SH" >&2; exit 1; }
INSTALL_SH="$(cd "$(dirname "$INSTALL_SH")" && pwd)/$(basename "$INSTALL_SH")"

PASS=0; FAIL=0; FAILS=()
ok(){ PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); FAILS+=("$1"); printf 'FAIL  %s\n' "$1"; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

# The fake linux-arm64 "claude" the stub download serves, and its real sha256
# (so the wrapper's real sha256sum check passes against the stub manifest).
# Stub shebangs point at the running bash (Termux has no /usr/bin/env), so the
# suite is portable between Termux and a desktop shell.
BASH_BIN="$(command -v bash)"
FAKE_BIN_SRC="$ROOT/fake-claude"
printf '#!%s\n[ -n "${PRELOAD_CAPTURE:-}" ] && printf "%%s\\n" "${BUN_OPTIONS:-}" > "$PRELOAD_CAPTURE"\necho "9.9.9 (fake claude)"\nexit 0\n' "$BASH_BIN" > "$FAKE_BIN_SRC"
FAKE_SHA="$(sha256sum "$FAKE_BIN_SRC" | cut -d' ' -f1)"
TEST_GLIBC_LD="/fake/ld-linux.so"
REAL_REALPATH="$(command -v realpath)"
export FAKE_BIN_SRC FAKE_SHA TEST_GLIBC_LD REAL_REALPATH

# --- stubs: only the network/device calls are faked; coreutils stay real ---
BIN="$ROOT/stub-bin"; mkdir -p "$BIN"
printf '#!%s\n' "$BASH_BIN" > "$BIN/curl"
cat >> "$BIN/curl" <<'CURL'
url=""; out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; -*) shift;; *) url="$1"; shift;; esac; done
case "$url" in
  *registry.npmjs.org*)
    [ "${FAKE_REGISTRY_FAIL:-0}" = 1 ] && exit 1
    printf '{"version":"%s"}\n' "${FAKE_LATEST:-9.9.9}"
    ;;
  *manifest.json*)
    [ "${FAKE_MANIFEST_FAIL:-0}" = 1 ] && exit 1
    checksum="$FAKE_SHA"
    [ "${FAKE_CHECKSUM_MISMATCH:-0}" = 1 ] && checksum=0000000000000000000000000000000000000000000000000000000000000000
    printf '{"platforms":{"linux-arm64":{"checksum":"%s"}}}\n' "$checksum"
    ;;
  *linux-arm64/claude*)
    [ "${FAKE_DOWNLOAD_FAIL:-0}" = 1 ] && exit 1
    cat "$FAKE_BIN_SRC" > "$out"
    [ -n "${FAKE_DL_DELAY:-}" ] && sleep "$FAKE_DL_DELAY"
    ;;
esac
exit 0
CURL
printf '#!%s\n' "$BASH_BIN" > "$BIN/patchelf"
cat >> "$BIN/patchelf" <<'PE'
for a in "$@"; do case "$a" in --print-interpreter) echo "${TEST_GLIBC_LD:-/fake/ld}";; esac; done
exit 0
PE
printf '#!%s\n' "$BASH_BIN" > "$BIN/timeout"
cat >> "$BIN/timeout" <<'TO'
# Drives smoke_test's exit code by the SMOKE env var, ignoring the real args.
case "${SMOKE:-healthy}" in
  healthy) exit 0 ;;
  crash)   echo "Bad system call" >&2; exit 139 ;;
  timeout) exit 124 ;;
  *)       exit 0 ;;
esac
TO
printf '#!%s\n' "$BASH_BIN" > "$BIN/realpath"
cat >> "$BIN/realpath" <<'RP'
case "${REALPATH_MODE:-${REALPATH_FAIL:+fail}}" in
  fail)
    echo "realpath: forced failure for wrapper regression test" >&2
    exit 1
    ;;
  empty)
    exit 0
    ;;
  absolute)
    printf '%s\n' "${REALPATH_ABSOLUTE_RESULT:?}"
    exit 0
    ;;
esac
exec "$REAL_REALPATH" "$@"
RP
chmod +x "$BIN/curl" "$BIN/patchelf" "$BIN/timeout" "$BIN/realpath"

# A deliberately minimal command PATH with no realpath entry. This proves the
# wrapper handles command-not-found, rather than only a command returning 1.
NO_REALPATH_BIN="$ROOT/no-realpath-bin"; mkdir -p "$NO_REALPATH_BIN"
for tool in cat date grep ls sort stat; do
  tool_path="$(command -v "$tool")"
  printf '#!%s\nexec "%s" "$@"\n' "$BASH_BIN" "$tool_path" > "$NO_REALPATH_BIN/$tool"
  chmod +x "$NO_REALPATH_BIN/$tool"
done

# Extract install.sh's wrapper heredoc and let bash generate the real wrapper,
# baking in the test paths. Prints the wrapper path.
gen_wrapper() {
  local vdir="$1"
  local wrapper_home="${2:-$vdir/../home}"
  local wrapper="$vdir/../claude"
  awk '/cat > .* <<EOF/{p=1} p{print} p&&/^EOF$/{exit}' "$INSTALL_SH" \
    | WRAPPER="$wrapper" VERSIONS_DIR="$vdir" GLIBC_LD="$TEST_GLIBC_LD" \
      PATCHELF="$BIN/patchelf" HOME="$wrapper_home" "$BASH_BIN"
  chmod +x "$wrapper"
  printf '%s' "$wrapper"
}

run_wrapper() {   # $1 wrapper, $2 stderr file, rest = wrapper args
  local w="$1" errf="$2"; shift 2
  # Invoke through bash rather than exec-ing $w: the generated wrapper's shebang
  # points at Termux's bash path, which does not exist off-device.
  PATH="${WRAPPER_TEST_PATH:-$BIN:$PATH}" "$BASH_BIN" "$w" "$@" >/dev/null 2>"$errf" || true
}

# Create the versions dir plus the ~/.local/share/claude tree install.sh always
# makes, so the wrapper's setdns write does not fail in the sandbox.
newcase(){ mkdir -p "$ROOT/$1/versions" "$ROOT/$1/home/.local/share/claude"; V="$ROOT/$1/versions"; }

echo "=== Scenario 1: single healthy update installs cleanly ==="
newcase s1
W="$(gen_wrapper "$V")"
printf 'orphan\n' > "$V/8.8.8.123.tmp"
printf 'active\n' > "$V/8.8.8.456.tmp"
touch -d '2 days ago' "$V/8.8.8.123.tmp"
SMOKE=healthy run_wrapper "$W" "$ROOT/s1.err" --update-now
[ -f "$V/9.9.9" ] && ok "s1: 9.9.9 installed" || no "s1: 9.9.9 NOT installed"
[ "$(cat "$V/.verified" 2>/dev/null)" = "9.9.9" ] && ok "s1: marked verified" || no "s1: not verified"
[ ! -e "$V/8.8.8.123.tmp" ] && ok "s1: stale orphan .tmp removed" || no "s1: stale orphan .tmp retained"
[ -e "$V/8.8.8.456.tmp" ] && ok "s1: fresh .tmp preserved" || no "s1: fresh .tmp wrongly removed"
stamp_age=$(( $(date +%s) - $(stat -c%Y "$V/.last-update-check") ))
[ "$stamp_age" -le 10 ] && ok "s1: successful update keeps the full 24-hour cadence" || no "s1: success stamp unexpectedly backdated"
if grep -q 'checksum mismatch' "$ROOT/s1.err"; then no "s1: false checksum mismatch"; else ok "s1: clean stderr"; fi

echo
echo "=== Scenario 2: two concurrent launches do NOT race ==="
newcase s2
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
W="$(gen_wrapper "$V")"
grep -Fq 'tmp="$new_bin.$$.tmp"' "$W" \
  && ok "s2: generated wrapper uses per-process staging paths" \
  || no "s2: generated wrapper reverted to a shared staging path"
SMOKE=healthy FAKE_DL_DELAY="${TEST_DL_DELAY:-2}" run_wrapper "$W" "$ROOT/s2a.err" --update-now &
sleep "${TEST_LAUNCH_GAP:-0.3}"
SMOKE=healthy run_wrapper "$W" "$ROOT/s2b.err" --update-now
wait
if grep -q 'checksum mismatch\|No such file' "$ROOT/s2a.err" "$ROOT/s2b.err"; then no "s2: race symptom present"; else ok "s2: no race symptom under concurrency"; fi
[ -f "$V/9.9.9" ] && ok "s2: 9.9.9 installed by winner" || no "s2: 9.9.9 not installed"
if ls "$V"/*.tmp >/dev/null 2>&1; then no "s2: stray .tmp left"; else ok "s2: no stray .tmp"; fi

echo
echo "=== Scenario 2b: fresh update lock blocks; stale lock is stolen ==="
newcase s2-lock-fresh
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
mkdir "$V/.update.lock"
W="$(gen_wrapper "$V")"
SMOKE=healthy run_wrapper "$W" "$ROOT/s2-lock-fresh.err" --update-now
[ ! -e "$V/9.9.9" ] \
  && ok "s2 lock: fresh lock blocks a second updater" \
  || no "s2 lock: fresh lock did not block a second updater"

newcase s2-lock-stale
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
mkdir "$V/.update.lock"
touch -d '20 minutes ago' "$V/.update.lock"
W="$(gen_wrapper "$V")"
SMOKE=healthy run_wrapper "$W" "$ROOT/s2-lock-stale.err" --update-now
[ -e "$V/9.9.9" ] \
  && ok "s2 lock: stale lock is stolen and update proceeds" \
  || no "s2 lock: stale lock prevented the update"

echo
echo "=== Scenario 3: a crashing new build is blocklisted, cached kept ==="
newcase s3
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
W="$(gen_wrapper "$V")"
SMOKE=crash run_wrapper "$W" "$ROOT/s3.err" --update-now
if grep -qxF "9.9.9" "$V/.blocklist" 2>/dev/null; then ok "s3: crashing build blocklisted"; else no "s3: not blocklisted"; fi
[ -f "$V/9.9.9" ] && no "s3: crashing build installed" || ok "s3: crashing build not installed"

echo
echo "=== Scenario 4: an inconclusive (timed-out) probe is NOT blocklisted ==="
newcase s4
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
W="$(gen_wrapper "$V")"
SMOKE=timeout run_wrapper "$W" "$ROOT/s4.err" --update-now
if grep -qxF "9.9.9" "$V/.blocklist" 2>/dev/null; then no "s4: timeout wrongly blocklisted a good build"; else ok "s4: timeout not blocklisted"; fi

echo
echo "=== Scenario 5: preload is relative, with absolute fallback ==="
newcase s5
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
touch "$V/.last-update-check"
W="$(gen_wrapper "$V")"
mkdir -p "$ROOT/s5/work/deep"
PRELOAD_CAPTURE="$ROOT/s5/relative.opts" run_wrapper "$W" "$ROOT/s5-relative.err"
relative_opts="$(cat "$ROOT/s5/relative.opts" 2>/dev/null)"
relative_spec="${relative_opts#--preload }"
case "$relative_spec" in
  ./*|../*) ok "s5: generated wrapper passes a relative preload" ;;
  *) no "s5: preload is not explicitly relative: $relative_spec" ;;
esac
setdns="$V/../home/.local/share/claude/setdns.js"
if [ -n "$relative_spec" ] \
  && [ "$(cd "$PWD" && realpath "$relative_spec" 2>/dev/null)" = "$(realpath "$setdns")" ]; then
  ok "s5: relative preload resolves to setdns.js"
else
  no "s5: relative preload does not resolve to setdns.js"
fi
REALPATH_FAIL=1 PRELOAD_CAPTURE="$ROOT/s5/fallback.opts" run_wrapper "$W" "$ROOT/s5-fallback.err"
fallback_opts="$(cat "$ROOT/s5/fallback.opts" 2>/dev/null)"
[ "$fallback_opts" = "--preload $setdns" ] \
  && ok "s5: realpath failure falls back to absolute preload" \
  || no "s5: realpath failure did not preserve absolute preload: $fallback_opts"
[ ! -s "$ROOT/s5-fallback.err" ] \
  && ok "s5: realpath failure adds no stderr" \
  || no "s5: realpath failure emitted stderr"

REALPATH_MODE=empty PRELOAD_CAPTURE="$ROOT/s5/empty.opts" run_wrapper "$W" "$ROOT/s5-empty.err"
[ "$(cat "$ROOT/s5/empty.opts" 2>/dev/null)" = "--preload $setdns" ] \
  && ok "s5: empty realpath output falls back to absolute preload" \
  || no "s5: empty realpath output did not use absolute fallback"

unexpected_absolute="$ROOT/not-the-preload.js"
REALPATH_MODE=absolute REALPATH_ABSOLUTE_RESULT="$unexpected_absolute" \
  PRELOAD_CAPTURE="$ROOT/s5/absolute.opts" run_wrapper "$W" "$ROOT/s5-absolute.err"
[ "$(cat "$ROOT/s5/absolute.opts" 2>/dev/null)" = "--preload $setdns" ] \
  && ok "s5: unexpected absolute realpath output uses safe fallback" \
  || no "s5: unexpected absolute realpath output was trusted"

WRAPPER_TEST_PATH="$NO_REALPATH_BIN" PRELOAD_CAPTURE="$ROOT/s5/missing-realpath.opts" \
  run_wrapper "$W" "$ROOT/s5-missing-realpath.err"
[ "$(cat "$ROOT/s5/missing-realpath.opts" 2>/dev/null)" = "--preload $setdns" ] \
  && ok "s5: absent realpath command falls back to absolute preload" \
  || no "s5: absent realpath command broke the preload"
[ ! -s "$ROOT/s5-missing-realpath.err" ] \
  && ok "s5: absent realpath command adds no stderr" \
  || no "s5: absent realpath command emitted stderr"

BUN_OPTIONS='--smol --conditions=test' PRELOAD_CAPTURE="$ROOT/s5/appended.opts" \
  run_wrapper "$W" "$ROOT/s5-appended.err"
appended_opts="$(cat "$ROOT/s5/appended.opts" 2>/dev/null)"
[ "$appended_opts" = "$relative_opts --smol --conditions=test" ] \
  && ok "s5: existing BUN_OPTIONS is preserved exactly" \
  || no "s5: existing BUN_OPTIONS changed: $appended_opts"

mkdir -p "$ROOT/s5/physical-cwd"
ln -s "$ROOT/s5/physical-cwd" "$ROOT/s5/logical-cwd"
(
  cd "$ROOT/s5/logical-cwd" || exit
  PRELOAD_CAPTURE="$ROOT/s5/symlink.opts" run_wrapper "$W" "$ROOT/s5-symlink.err"
)
symlink_opts="$(cat "$ROOT/s5/symlink.opts" 2>/dev/null)"
symlink_spec="${symlink_opts#--preload }"
if [ -n "$symlink_spec" ] \
  && [ "$(cd "$ROOT/s5/physical-cwd" && realpath "$symlink_spec" 2>/dev/null)" = "$(realpath "$setdns")" ]; then
  ok "s5: symlinked CWD resolves preload from physical directory"
else
  no "s5: symlinked CWD produced invalid preload: $symlink_opts"
fi

mkdir -p "$ROOT/s5/deleted-cwd"
(
  cd "$ROOT/s5/deleted-cwd" || exit
  rmdir "$ROOT/s5/deleted-cwd"
  PRELOAD_CAPTURE="$ROOT/s5/deleted.opts" run_wrapper "$W" "$ROOT/s5-deleted.err"
)
deleted_opts="$(cat "$ROOT/s5/deleted.opts" 2>/dev/null)"
case "$deleted_opts" in
  "--preload ./"*|"--preload ../"*|"--preload $setdns")
    ok "s5: deleted CWD retains an explicit safe preload specifier"
    ;;
  *)
    no "s5: deleted CWD produced an unsafe preload: opts=$deleted_opts stderr=$(tr '\n' ' ' < "$ROOT/s5-deleted.err")"
    ;;
esac

echo
echo "=== Scenario 5b: missing and zero-byte setdns never preload empty files ==="
newcase s5-missing-setdns
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
touch "$V/.last-update-check"
missing_home="$ROOT/s5-missing-setdns/no-parent/home"
W="$(gen_wrapper "$V" "$missing_home")"
PRELOAD_CAPTURE="$ROOT/s5-missing-setdns.opts" run_wrapper "$W" "$ROOT/s5-missing-setdns.err"
missing_opts="$(cat "$ROOT/s5-missing-setdns.opts" 2>/dev/null)"
[ -z "$missing_opts" ] \
  && ok "s5 guard: missing unwritable setdns is not preloaded" \
  || no "s5 guard: missing setdns was preloaded: $missing_opts"

newcase s5-zero-setdns
cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
touch "$V/.last-update-check"
ln -s /dev/null "$ROOT/s5-zero-setdns/home/.local/share/claude/setdns.js"
W="$(gen_wrapper "$V")"
PRELOAD_CAPTURE="$ROOT/s5-zero-setdns.opts" run_wrapper "$W" "$ROOT/s5-zero-setdns.err"
zero_opts="$(cat "$ROOT/s5-zero-setdns.opts" 2>/dev/null)"
[ -z "$zero_opts" ] \
  && ok "s5 guard: zero-byte setdns is not preloaded" \
  || no "s5 guard: zero-byte setdns was preloaded: $zero_opts"

echo
echo "=== Scenario 6: failed checks retry in roughly one hour ==="
check_retry_stamp() {
  local name="$1" failure_var="$2"
  newcase "s6-$name"
  cp "$FAKE_BIN_SRC" "$V/1.0.0"; echo "1.0.0" > "$V/.verified"
  W="$(gen_wrapper "$V")"
  if [ "$name" = registry ]; then
    printf 'orphan\n' > "$V/7.7.7.123.tmp"
    printf 'active\n' > "$V/7.7.7.456.tmp"
    touch -d '2 days ago' "$V/7.7.7.123.tmp"
  fi
  export "$failure_var=1"
  SMOKE=healthy run_wrapper "$W" "$ROOT/s6-$name.err" --update-now
  unset "$failure_var"
  local now stamp age
  now="$(date +%s)"
  stamp="$(stat -c%Y "$V/.last-update-check" 2>/dev/null || echo 0)"
  age=$((now - stamp))
  if [ "$age" -ge 82790 ] && [ "$age" -le 82810 ]; then
    ok "s6 $name: failure schedules retry in about one hour"
  else
    no "s6 $name: stamp age is $age seconds, expected about 82800"
  fi
  if [ "$name" = registry ]; then
    [ ! -e "$V/7.7.7.123.tmp" ] \
      && ok "s6 registry: failed check removes stale orphan .tmp" \
      || no "s6 registry: failed check retained stale orphan .tmp"
    [ -e "$V/7.7.7.456.tmp" ] \
      && ok "s6 registry: failed check preserves fresh .tmp" \
      || no "s6 registry: failed check wrongly removed fresh .tmp"
  fi
}
check_retry_stamp registry FAKE_REGISTRY_FAIL
registry_v="$V"; registry_w="$W"
check_retry_stamp download FAKE_DOWNLOAD_FAIL
check_retry_stamp manifest FAKE_MANIFEST_FAIL
check_retry_stamp checksum FAKE_CHECKSUM_MISMATCH

# Move the registry-failure stamp just beyond its remaining hour and prove that
# an ordinary launch, without --update-now, attempts and installs the update.
V="$registry_v"; W="$registry_w"
stamp="$(stat -c%Y "$V/.last-update-check")"
touch -d "@$((stamp - 3601))" "$V/.last-update-check"
SMOKE=healthy run_wrapper "$W" "$ROOT/s6-registry-retry.err"
[ -f "$V/9.9.9" ] \
  && ok "s6 registry: ordinary launch retries after the shortened interval" \
  || no "s6 registry: ordinary launch did not retry after one hour"

echo
echo "=================================="
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then printf ' - %s\n' "${FAILS[@]}"; exit 1; fi
exit 0
