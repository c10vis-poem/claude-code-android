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
[ "${REALPATH_FAIL:-0}" = 1 ] && exit 1
exec "$REAL_REALPATH" "$@"
RP
chmod +x "$BIN/curl" "$BIN/patchelf" "$BIN/timeout" "$BIN/realpath"

# Extract install.sh's wrapper heredoc and let bash generate the real wrapper,
# baking in the test paths. Prints the wrapper path.
gen_wrapper() {
  local vdir="$1"
  local wrapper="$vdir/../claude"
  awk '/cat > .* <<EOF/{p=1} p{print} p&&/^EOF$/{exit}' "$INSTALL_SH" \
    | WRAPPER="$wrapper" VERSIONS_DIR="$vdir" GLIBC_LD="$TEST_GLIBC_LD" \
      PATCHELF="$BIN/patchelf" HOME="$vdir/../home" bash
  chmod +x "$wrapper"
  printf '%s' "$wrapper"
}

run_wrapper() {   # $1 wrapper, $2 stderr file, rest = wrapper args
  local w="$1" errf="$2"; shift 2
  # Invoke through bash rather than exec-ing $w: the generated wrapper's shebang
  # points at Termux's bash path, which does not exist off-device.
  PATH="$BIN:$PATH" bash "$w" "$@" >/dev/null 2>"$errf" || true
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
SMOKE=healthy FAKE_DL_DELAY=2 run_wrapper "$W" "$ROOT/s2a.err" --update-now &
sleep 0.3
SMOKE=healthy run_wrapper "$W" "$ROOT/s2b.err" --update-now
wait
if grep -q 'checksum mismatch\|No such file' "$ROOT/s2a.err" "$ROOT/s2b.err"; then no "s2: race symptom present"; else ok "s2: no race symptom under concurrency"; fi
[ -f "$V/9.9.9" ] && ok "s2: 9.9.9 installed by winner" || no "s2: 9.9.9 not installed"
if ls "$V"/*.tmp >/dev/null 2>&1; then no "s2: stray .tmp left"; else ok "s2: no stray .tmp"; fi

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
