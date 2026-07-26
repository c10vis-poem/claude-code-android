#!/usr/bin/env bash
# Regression tests for the install-time native-binary smoke probes.
#
# Both installers run with `set -e`. The probe must remain in an if/else guard
# so expected crash/timeout statuses reach the existing classification logic.

set -u

INSTALL_SH="${1:-install.sh}"
MIGRATE_SH="${2:-migrate.sh}"
[ -f "$INSTALL_SH" ] || { echo "install.sh not found: $INSTALL_SH" >&2; exit 1; }
[ -f "$MIGRATE_SH" ] || { echo "migrate.sh not found: $MIGRATE_SH" >&2; exit 1; }

PASS=0
FAIL=0
FAILS=()
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

ok(){ PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); FAILS+=("$1"); printf 'FAIL  %s\n' "$1"; }

extract_probe() {
  awk '
    /^info "smoke-testing/ { printing=1 }
    printing { print }
    printing && /ok "(binary|new binary) launches cleanly/ { saw_healthy=1 }
    saw_healthy && /^fi$/ { exit }
  ' "$1"
}

make_harness() {
  local source="$1" output="$2" mode="$3"
  local probe="$ROOT/$mode.probe"
  extract_probe "$source" > "$probe"
  {
    printf '#!%s\n' "$(command -v bash)"
    cat <<'HARNESS'
set -euo pipefail
warn(){ printf 'WARN:%s\n' "$1"; }
ok(){ printf 'OK:%s\n' "$1"; }
info(){ printf 'INFO:%s\n' "$1"; }
fail(){ printf 'CONTROLLED_FAIL:%s\n' "$1"; exit 1; }
on_err(){ printf 'ERR_TRAP\n'; exit 97; }
timeout(){ return "${SMOKE_RC:?}"; }
VERSIONS_DIR="${HARNESS_ROOT:?}/versions"
BINARY="$VERSIONS_DIR/9.9.9"
LATEST=9.9.9
mkdir -p "$VERSIONS_DIR"
printf 'fake\n' > "$BINARY"
HARNESS
    [ "$mode" = migrate ] && printf 'trap on_err ERR\n'
    cat "$probe"
    printf 'printf "REACHED_AFTER_CLASSIFICATION\\n"\n'
  } > "$output"
  chmod +x "$output"
}

run_case() {
  local mode="$1" status="$2" expected_rc="$3" expected_text="$4"
  local source harness="$ROOT/$mode-$status.sh" output="$ROOT/$mode-$status.out"
  if [ "$mode" = install ]; then source="$INSTALL_SH"; else source="$MIGRATE_SH"; fi
  make_harness "$source" "$harness" "$mode"
  HARNESS_ROOT="$ROOT/$mode-$status" SMOKE_RC="$status" bash "$harness" >"$output" 2>&1
  local rc=$?

  [ "$rc" -eq "$expected_rc" ] \
    && ok "$mode status $status: expected exit $expected_rc" \
    || no "$mode status $status: exit $rc, expected $expected_rc"
  grep -Fq "$expected_text" "$output" \
    && ok "$mode status $status: classification warning reached" \
    || no "$mode status $status: classification warning missing"
  if grep -Fq 'ERR_TRAP' "$output"; then
    no "$mode status $status: ERR trap fired on expected probe result"
  else
    ok "$mode status $status: ERR trap stayed quiet"
  fi
  if [ "$mode" = install ] || [ "$status" -eq 124 ]; then
    grep -Fq 'REACHED_AFTER_CLASSIFICATION' "$output" \
      && ok "$mode status $status: script continued after classification" \
      || no "$mode status $status: script died before continuing"
  fi
}

echo "=== install.sh smoke classification under errexit ==="
run_case install 139 0 'crashes on this device'
run_case install 124 0 'Could not fully verify'

echo
echo "=== migrate.sh smoke classification with ERR trap ==="
# A proven crash intentionally aborts migration through fail(), after guidance.
run_case migrate 139 1 'crashes on this device'
run_case migrate 124 0 'Could not fully verify'

echo
echo "=================================="
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then printf ' - %s\n' "${FAILS[@]}"; exit 1; fi
