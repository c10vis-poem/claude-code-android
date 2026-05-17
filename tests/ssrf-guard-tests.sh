#!/usr/bin/env bash
# ssrf-guard-tests.sh -- test harness for ssrf-guard.sh
#
# Feeds a suite of JSON PreToolUse payloads to the guard and asserts
# the expected block/allow behavior. Works against any guard version.
#
# Usage:
#   bash tests/ssrf-guard-tests.sh examples/ssrf-guard.sh
#   bash tests/ssrf-guard-tests.sh examples/ssrf-guard.v2.sh

HOOK="${1:-examples/ssrf-guard.sh}"

if [ ! -f "$HOOK" ]; then
  echo "Hook not found: $HOOK" >&2
  exit 1
fi

PASS=0
FAIL=0
FAILS=()

run_test() {
  local desc="$1"
  local expected_exit="$2"
  local payload="$3"

  local actual_exit=0
  local stderr_out
  stderr_out=$(echo "$payload" | bash "$HOOK" 2>&1 >/dev/null) || actual_exit=$?

  if [ "$actual_exit" = "$expected_exit" ]; then
    PASS=$((PASS+1))
    printf 'PASS  %s\n' "$desc"
  else
    FAIL=$((FAIL+1))
    FAILS+=("$desc (expected $expected_exit, got $actual_exit) :: $stderr_out")
    printf 'FAIL  %s  (expected %s, got %s)\n' "$desc" "$expected_exit" "$actual_exit"
  fi
}

wf() { printf '{"tool_name":"WebFetch","tool_input":{"url":"%s"}}' "$1"; }
ws() { printf '{"tool_name":"WebSearch","tool_input":{"query":"%s"}}' "$1"; }

echo "=== Blocked: loopback ==="
run_test "loopback localhost"              2 "$(wf 'http://localhost/')"
run_test "loopback 127.0.0.1"              2 "$(wf 'http://127.0.0.1/')"
run_test "loopback 127.1 short-form"       2 "$(wf 'http://127.1/')"
run_test "loopback 127.0.1 3-part"         2 "$(wf 'http://127.0.1/')"
run_test "loopback decimal 2130706433"     2 "$(wf 'http://2130706433/')"
run_test "loopback hex 0x7f000001"         2 "$(wf 'http://0x7f000001/')"
run_test "loopback octal 0177.0.0.1"       2 "$(wf 'http://0177.0.0.1/')"
run_test "loopback octal all 0177.0.0.01"  2 "$(wf 'http://0177.0.0.01/')"
run_test "loopback octal combined"         2 "$(wf 'http://017700000001/')"
run_test "loopback 127.42.42.42 in /8"     2 "$(wf 'http://127.42.42.42/')"

echo
echo "=== Blocked: private ranges ==="
run_test "10.0.0.1 private /8"             2 "$(wf 'http://10.0.0.1/')"
run_test "172.16.0.1 private"              2 "$(wf 'http://172.16.0.1/')"
run_test "172.31.255.1 private upper"      2 "$(wf 'http://172.31.255.1/')"
run_test "192.168.1.1 private"             2 "$(wf 'http://192.168.1.1/')"
run_test "192.168.1.1 private octal form"  2 "$(wf 'http://0300.0250.0001.0001/')"
run_test "169.254.169.254 metadata IP"     2 "$(wf 'http://169.254.169.254/')"
run_test "100.64.0.1 CGNAT"                2 "$(wf 'http://100.64.0.1/')"
run_test "0.0.0.0 reserved"                2 "$(wf 'http://0.0.0.0/')"
run_test "255.255.255.255 broadcast"       2 "$(wf 'http://255.255.255.255/')"
run_test "240.0.0.1 reserved /4"           2 "$(wf 'http://240.0.0.1/')"

echo
echo "=== Blocked: cloud metadata hostnames ==="
run_test "metadata.google.internal"        2 "$(wf 'http://metadata.google.internal/')"
run_test "metadata.goog"                   2 "$(wf 'http://metadata.goog/')"
run_test "metadata.internal"               2 "$(wf 'http://metadata.internal/')"

echo
echo "=== Blocked: IPv6 ==="
run_test "IPv6 loopback ::1"               2 "$(wf 'http://[::1]/')"
run_test "IPv6 link-local fe80::1"         2 "$(wf 'http://[fe80::1]/')"
run_test "IPv6 ULA fc00::"                 2 "$(wf 'http://[fc00::1]/')"
run_test "IPv6 unspecified ::"             2 "$(wf 'http://[::]/')"
run_test "IPv4-mapped ::ffff:127.0.0.1"    2 "$(wf 'http://[::ffff:127.0.0.1]/')"

echo
echo "=== Blocked: bad schemes ==="
run_test "ftp scheme"                      2 "$(wf 'ftp://example.com/')"
run_test "file scheme"                     2 "$(wf 'file:///etc/passwd')"
run_test "javascript scheme"               2 "$(wf 'javascript:alert(1)')"
run_test "gopher scheme"                   2 "$(wf 'gopher://internal/')"

echo
echo "=== Allowed: public ==="
run_test "public example.com"              0 "$(wf 'http://example.com/')"
run_test "public 8.8.8.8 (Google DNS)"     0 "$(wf 'http://8.8.8.8/')"
run_test "https github.com"                0 "$(wf 'https://github.com/')"
run_test "public IPv6 2001:db8::1"         0 "$(wf 'http://[2001:db8::1]/')"
run_test "public with port"                0 "$(wf 'http://example.com:8443/')"
run_test "public with path and query"      0 "$(wf 'https://example.com/path?q=1')"

echo
echo "=== WebSearch: bare queries pass through ==="
run_test "bare search query"               0 "$(ws 'python list comprehension tutorial')"
run_test "search mentioning IP text"       0 "$(ws '127.0.0.1 exploit CVE analysis')"
run_test "search mentioning private range" 0 "$(ws '192.168.1.1 router admin default')"

echo
echo "=== WebSearch: URL queries follow URL rules ==="
run_test "WebSearch URL to localhost"      2 "$(ws 'http://localhost/')"
run_test "WebSearch URL to public"         0 "$(ws 'http://example.com/')"
run_test "WebSearch URL to 127.1"          2 "$(ws 'http://127.1/')"
run_test "WebSearch URL octal 0177.0.0.1"  2 "$(ws 'http://0177.0.0.1/')"

echo
echo "=== Other tools pass through ==="
run_test "Bash tool ignored"               0 '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
run_test "Read tool ignored"               0 '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"}}'
run_test "Edit tool ignored"               0 '{"tool_name":"Edit","tool_input":{"file_path":"foo"}}'

echo
echo "=== Edge cases ==="
run_test "malformed URL"                   2 "$(wf 'http://[bad')"
run_test "empty URL"                       2 "$(wf '')"
run_test "uppercase scheme HTTP://"        0 "$(wf 'HTTP://example.com/')"
run_test "mixed case hostname"             0 "$(wf 'http://Example.COM/')"

echo
echo "=== Summary ==="
echo "Hook tested: $HOOK"
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo
  echo "Failures:"
  for f in "${FAILS[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
