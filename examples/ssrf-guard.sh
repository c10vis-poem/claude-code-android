#!/usr/bin/env bash
# ssrf-guard.sh -- PreToolUse hook for WebFetch and WebSearch tools
#
# Blocks requests targeting internal, private, loopback, link-local,
# and reserved IP ranges. Only http:// and https:// schemes are allowed.
#
# Uses Node's URL parser for RFC 3986-compliant parsing and hostname
# normalization. This matters because Claude Code's WebFetch uses the
# same URL parser, so short-form IPs (127.1), hex forms (0x7f000001),
# and decimal forms (2130706433) that Node normalizes to 127.0.0.1 at
# parse time are caught here with the same normalization the actual
# fetch will apply.
#
# Known limitations:
# - Does NOT perform DNS resolution. A hostname that resolves to a
#   private IP (DNS rebinding) is not caught by this guard. Pair with
#   network-level egress controls for stricter protection.
# - Requires Node.js on PATH (reasonable since Claude Code needs Node).
# - Requires jq for JSON parsing.
#
# Exit codes:
#   0 = allow the request
#   2 = block the request (with JSON reason on stderr)

set -euo pipefail

block() {
  local reason="$1"
  echo "{\"error\": \"SSRF_BLOCKED\", \"reason\": \"$reason\"}" >&2
  exit 2
}

guard_error() {
  local reason="$1"
  echo "{\"error\": \"SSRF_GUARD_ERROR\", \"reason\": \"$reason\"}" >&2
  exit 2
}

# --- Dependency checks ---
command -v jq >/dev/null 2>&1 || guard_error "jq not found; cannot parse hook input"
command -v node >/dev/null 2>&1 || guard_error "node not found; cannot parse URL"

# --- Read hook input ---
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only process WebFetch and WebSearch calls
if [ "$TOOL_NAME" != "WebFetch" ] && [ "$TOOL_NAME" != "WebSearch" ]; then
  exit 0
fi

# Extract the URL or query
# WebFetch -> tool_input.url
# WebSearch -> tool_input.query (may or may not contain a URL)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // .tool_input.query // ""')

if [ -z "$URL" ]; then
  block "Empty URL or query"
fi

# WebSearch bare-query exception:
# If tool is WebSearch and the query does not contain "://", it is a
# search query, not a URL. Allow without further checks.
if [ "$TOOL_NAME" = "WebSearch" ] && ! echo "$URL" | grep -qE '://'; then
  exit 0
fi

# --- Parse the URL via Node ---
# RFC 3986-compliant normalization: short-form IPs (127.1), hex
# (0x7f000001), decimal (2130706433), percent-encoded hostnames, and
# IPv6 bracket syntax are all normalized. Userinfo is discarded.
#
# Output format:
#   scheme=<scheme>
#   host=<hostname>
#   ipv6=<0 or 1>
PARSED=$(node -e '
  try {
    const u = new URL(process.argv[1]);
    let h = u.hostname;
    const isBracketed = h.startsWith("[") && h.endsWith("]");
    if (isBracketed) h = h.slice(1, -1);
    let ipv6Flag = isBracketed;

    // IPv4-mapped IPv6: ::ffff:X:Y (hex form after Node normalization) or
    // ::ffff:a.b.c.d. Unwrap to plain IPv4 so IPv4 range checks apply.
    if (isBracketed && h.startsWith("::ffff:")) {
      const tail = h.slice(7);
      if (/^\d+\.\d+\.\d+\.\d+$/.test(tail)) {
        h = tail;
        ipv6Flag = false;
      } else {
        const m = tail.match(/^([0-9a-f]+):([0-9a-f]+)$/);
        if (m) {
          const hi = parseInt(m[1], 16);
          const lo = parseInt(m[2], 16);
          h = [(hi >> 8) & 255, hi & 255, (lo >> 8) & 255, lo & 255].join(".");
          ipv6Flag = false;
        }
      }
    }

    console.log("scheme=" + u.protocol.replace(":", ""));
    console.log("host=" + h.toLowerCase());
    console.log("ipv6=" + (ipv6Flag ? "1" : "0"));
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
' "$URL" 2>&1) || block "URL could not be parsed: $PARSED"

SCHEME=$(echo "$PARSED" | grep '^scheme=' | cut -d= -f2-)
HOST=$(echo "$PARSED" | grep '^host=' | cut -d= -f2-)
IS_IPV6=$(echo "$PARSED" | grep '^ipv6=' | cut -d= -f2-)

# --- Scheme check ---
if [ "$SCHEME" != "http" ] && [ "$SCHEME" != "https" ]; then
  block "Scheme '$SCHEME' is not allowed. Only http and https are permitted."
fi

if [ -z "$HOST" ]; then
  block "Could not extract hostname from URL."
fi

# --- Blocked hostnames ---
case "$HOST" in
  localhost|0.0.0.0)
    block "Loopback/localhost address ($HOST)."
    ;;
  metadata.google.internal|metadata.internal|metadata.goog)
    block "Cloud metadata hostname ($HOST)."
    ;;
esac

# --- IPv6 range checks ---
if [ "$IS_IPV6" = "1" ]; then
  case "$HOST" in
    ::1|::0:1|0:0:0:0:0:0:0:1|0000:0000:0000:0000:0000:0000:0000:0001)
      block "IPv6 loopback address (::1)."
      ;;
    ::|::0|0:0:0:0:0:0:0:0|0000:0000:0000:0000:0000:0000:0000:0000)
      block "IPv6 unspecified address (::)."
      ;;
  esac

  # Link-local fe80::/10 (fe80 through febf)
  if [[ "$HOST" =~ ^fe[89ab] ]]; then
    block "IPv6 link-local address (fe80::/10)."
  fi

  # Unique local fc00::/7
  if [[ "$HOST" =~ ^f[cd] ]]; then
    block "IPv6 unique local address (fc00::/7)."
  fi

  # IPv4-mapped (::ffff:x.x.x.x) -- unwrap and fall through to IPv4 checks
  if [[ "$HOST" =~ ^::ffff: ]]; then
    HOST="${HOST#::ffff:}"
  else
    # Any other IPv6 address is treated as public
    exit 0
  fi
fi

# --- IPv4 range checks ---
# At this point HOST is either a dotted-quad IPv4 (possibly via
# Node's normalization of short-form/decimal/hex inputs) or a regular
# hostname. Numeric checks apply only if the host is a dotted-quad.
if [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IFS='.' read -r O1 O2 O3 O4 <<< "$HOST"

  for octet in "$O1" "$O2" "$O3" "$O4"; do
    if ! [[ "$octet" =~ ^[0-9]+$ ]] || [ "$octet" -gt 255 ]; then
      block "Invalid IP octet ($octet) in $HOST."
    fi
  done

  [ "$O1" = "127" ] && block "Loopback range (127.0.0.0/8)."
  [ "$O1" = "10" ] && block "Private range (10.0.0.0/8)."
  [ "$O1" = "172" ] && [ "$O2" -ge 16 ] && [ "$O2" -le 31 ] && block "Private range (172.16.0.0/12)."
  [ "$O1" = "192" ] && [ "$O2" = "168" ] && block "Private range (192.168.0.0/16)."
  [ "$O1" = "169" ] && [ "$O2" = "254" ] && block "Link-local range (169.254.0.0/16)."
  [ "$O1" = "0" ] && block "Reserved range (0.0.0.0/8)."
  [ "$O1" = "100" ] && [ "$O2" -ge 64 ] && [ "$O2" -le 127 ] && block "Carrier-grade NAT range (100.64.0.0/10)."
  [ "$O1" = "192" ] && [ "$O2" = "0" ] && [ "$O3" = "0" ] && block "IETF protocol assignment range (192.0.0.0/24)."
  [ "$O1" = "192" ] && [ "$O2" = "0" ] && [ "$O3" = "2" ] && block "Documentation range (192.0.2.0/24 TEST-NET-1)."
  [ "$O1" = "198" ] && [ "$O2" = "51" ] && [ "$O3" = "100" ] && block "Documentation range (198.51.100.0/24 TEST-NET-2)."
  [ "$O1" = "203" ] && [ "$O2" = "0" ] && [ "$O3" = "113" ] && block "Documentation range (203.0.113.0/24 TEST-NET-3)."
  [ "$O1" = "198" ] && [ "$O2" -ge 18 ] && [ "$O2" -le 19 ] && block "Benchmarking range (198.18.0.0/15)."
  [ "$O1" -ge 240 ] && block "Reserved range (240.0.0.0/4)."
  [ "$O1" = "255" ] && [ "$O2" = "255" ] && [ "$O3" = "255" ] && [ "$O4" = "255" ] && block "Broadcast address (255.255.255.255)."
fi

exit 0
