# SSRF Guard -- WebFetch Safety Hook

A PreToolUse hook that blocks WebFetch requests targeting internal, private, and reserved IP ranges. Prevents server-side request forgery (SSRF) when Claude Code fetches URLs from MCP servers or tool outputs.

---

## What It Does

When Claude Code is about to make a WebFetch call, this hook intercepts the request and checks the target URL against a blocklist of dangerous destinations:

- **RFC 1918 private ranges**: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
- **Loopback**: 127.0.0.0/8, localhost, ::1
- **Link-local**: 169.254.0.0/16, fe80::/10
- **Carrier-grade NAT**: 100.64.0.0/10
- **Cloud metadata endpoints**: 169.254.169.254, metadata.google.internal, metadata.goog
- **IPv6 unspecified and ULA**: ::, fc00::/7
- **Non-HTTP schemes**: file://, ftp://, gopher://, data://, javascript://, etc.
- **Reserved/documentation ranges**: 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24, 198.18.0.0/15, 240.0.0.0/4

It also handles bypass vectors:

- URL-encoded IPs (%31%32%37.0.0.1 -> 127.0.0.1)
- Decimal IPs (2130706433 -> 127.0.0.1)
- Hex IPs (0x7f000001 -> 127.0.0.1)
- Octal IPs (0177.0.0.1 -> 127.0.0.1)
- IPv6-mapped IPv4 (::ffff:127.0.0.1)
- Double URL encoding (%2531 -> %31 -> 1)

If the URL is safe, the hook exits 0 (allow). If blocked, it exits 2 with a JSON error on stderr explaining why.

---

## Installation

### 1. Save the script

Save the script below as `.claude/hooks/ssrf-guard.sh` in your project or home directory:

```bash
mkdir -p ~/.claude/hooks
# Save the script content to ~/.claude/hooks/ssrf-guard.sh
chmod +x ~/.claude/hooks/ssrf-guard.sh
```

### 2. Register in settings.json

Add it to your Claude Code settings (project-level `.claude/settings.json` or user-level `~/.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch",
        "hook": "~/.claude/hooks/ssrf-guard.sh"
      }
    ]
  }
}
```

The `matcher` field ensures the hook only runs on WebFetch calls, not every tool invocation.

### 3. Verify dependencies

The script requires:

- bash 5.x
- jq 1.7+
- grep, sed, tr (standard on Linux and Termux)

On Termux:

```bash
pkg install jq -y
```

---

## How It Works

1. Claude Code sends the hook a JSON payload on stdin containing `tool_name` and `tool_input.url`
2. The hook checks if `tool_name` is `WebFetch` -- if not, it exits 0 (allow)
3. The URL is URL-decoded (two passes, to catch double encoding)
4. The scheme is checked -- only `http://` and `https://` are allowed
5. The hostname is extracted, stripping scheme, path, query, fragment, userinfo, port, and brackets
6. IPv6 addresses are checked against loopback, link-local, ULA, and unspecified ranges
7. IPv6-mapped IPv4 addresses are extracted and fall through to IPv4 checks
8. Cloud metadata hostnames and IPs are checked
9. The hostname is normalized (decimal, hex, and octal IP formats are converted to dotted-quad)
10. The dotted-quad is checked against all private and reserved ranges
11. If nothing matched, the request is allowed

---

## Known Limitations

- **DNS rebinding**: A hostname may resolve to a public IP when the hook checks it, then resolve to 127.0.0.1 when the actual HTTP request is made. This hook checks the URL string only, not the resolved IP.
- **HTTP redirects**: If the target returns a 3xx redirect to an internal IP, this hook will not catch it. The fetching tool must enforce its own redirect policy.
- **Hostname-based private IPs**: Hostnames like `internal.corp` that resolve to private IPs via DNS are not blocked. The hook does not perform DNS resolution.
- **Exotic encodings**: Unicode homoglyphs and other encodings beyond URL-encoding, decimal, hex, and octal are not covered.

---

## The Script

```bash
#!/usr/bin/env bash
# ssrf-guard.sh -- PreToolUse hook for WebFetch / URL-fetching tools
#
# Blocks requests targeting internal, private, loopback, link-local,
# and reserved IP ranges. Only http:// and https:// schemes are allowed.
#
# Exit codes:
#   0 = allow the request
#   2 = block the request (with JSON reason on stderr)

set -euo pipefail

# --- JSON block helper ---
block() {
  local reason="$1"
  echo "{\"error\": \"SSRF_BLOCKED\", \"reason\": \"$reason\"}" >&2
  exit 2
}

# --- Read hook input ---
INPUT=$(cat)

# Check jq is available
if ! command -v jq &>/dev/null; then
  echo '{"error": "SSRF_GUARD_ERROR", "reason": "jq not found; cannot parse hook input"}' >&2
  exit 2
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only process WebFetch calls
if [ "$TOOL_NAME" != "WebFetch" ]; then
  exit 0
fi

URL=$(echo "$INPUT" | jq -r '.tool_input.url // ""')

if [ -z "$URL" ]; then
  block "Empty URL"
fi

# =====================================================================
# 1. URL-DECODE the entire URL before any checks
#    Handles %HH encoding (e.g., %31%32%37 -> 127)
# =====================================================================
url_decode() {
  local input="$1"
  # Two passes to handle double-encoding (%2531 -> %31 -> 1)
  local decoded
  decoded=$(printf '%b' "$(echo "$input" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')")
  # Second pass
  decoded=$(printf '%b' "$(echo "$decoded" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')")
  echo "$decoded"
}

URL=$(url_decode "$URL")

# =====================================================================
# SCHEME CHECK
# Only allow http:// and https://
# =====================================================================
SCHEME=$(echo "$URL" | grep -oiE '^[a-zA-Z][a-zA-Z0-9+.-]*://' | tr '[:upper:]' '[:lower:]' || true)

if [ -z "$SCHEME" ]; then
  block "No scheme found. Only http:// and https:// are allowed."
fi

if [ "$SCHEME" != "http://" ] && [ "$SCHEME" != "https://" ]; then
  block "Scheme '${SCHEME%://}' is not allowed. Only http and https are permitted."
fi

# =====================================================================
# HOST EXTRACTION
# Strip scheme, path/query/fragment, userinfo, port, brackets
# =====================================================================
HOST=$(echo "$URL" | sed -E 's|^https?://||i' \
  | sed -E 's|[/?#].*||' \
  | sed -E 's|.*@||' \
  | sed -E 's|:[0-9]+$||')

if [ -z "$HOST" ]; then
  block "Could not extract hostname from URL."
fi

HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

# =====================================================================
# IPv6 HANDLING
# Detect bracketed IPv6 addresses and check against blocked ranges.
# Also detect IPv6-mapped IPv4 and extract the inner IPv4.
# =====================================================================

# Strip brackets for IPv6 analysis
IPV6_ADDR=""
if [[ "$HOST_LOWER" =~ ^\[.*\]$ ]]; then
  IPV6_ADDR="${HOST_LOWER:1:${#HOST_LOWER}-2}"
fi

if [ -n "$IPV6_ADDR" ]; then
  # Block ::1 (loopback) in any form
  case "$IPV6_ADDR" in
    ::1|::0:1|0:0:0:0:0:0:0:1|0000:0000:0000:0000:0000:0000:0000:0001)
      block "IPv6 loopback address (::1)."
      ;;
  esac

  # Block :: and ::0 (all-zeros / unspecified)
  case "$IPV6_ADDR" in
    ::|::0|0:0:0:0:0:0:0:0|0000:0000:0000:0000:0000:0000:0000:0000)
      block "IPv6 unspecified address (::)."
      ;;
  esac

  # Block fe80::/10 (link-local)
  if [[ "$IPV6_ADDR" =~ ^fe[89ab] ]]; then
    block "IPv6 link-local address (fe80::/10)."
  fi

  # Block fc00::/7 (ULA)
  if [[ "$IPV6_ADDR" =~ ^f[cd] ]]; then
    block "IPv6 unique local address (fc00::/7)."
  fi

  # IPv6-mapped IPv4 (::ffff:x.x.x.x)
  if [[ "$IPV6_ADDR" =~ ^::ffff: ]]; then
    MAPPED_IPV4="${IPV6_ADDR#::ffff:}"
    if [[ "$MAPPED_IPV4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      HOST_LOWER="$MAPPED_IPV4"
    else
      block "IPv6-mapped address with non-standard inner value."
    fi
  fi
fi

# =====================================================================
# CLOUD METADATA HOSTNAMES
# =====================================================================
case "$HOST_LOWER" in
  metadata.google.internal|metadata.internal)
    block "Cloud metadata hostname ($HOST_LOWER)."
    ;;
  169.254.169.254)
    block "Cloud metadata IP (169.254.169.254)."
    ;;
  metadata.goog)
    block "Cloud metadata hostname (metadata.goog)."
    ;;
esac

# =====================================================================
# BLOCKED HOSTNAMES
# =====================================================================
case "$HOST_LOWER" in
  localhost|0.0.0.0)
    block "Loopback/localhost address ($HOST_LOWER)."
    ;;
esac

# =====================================================================
# IP FORMAT NORMALIZATION
# Convert decimal, hex, and octal IPs to dotted-quad for range checks.
# =====================================================================

# Pure decimal integer (e.g., 2130706433 = 127.0.0.1)
if [[ "$HOST_LOWER" =~ ^[0-9]+$ ]] && [ "${#HOST_LOWER}" -gt 3 ]; then
  DECIMAL_IP="$HOST_LOWER"
  if [ "$DECIMAL_IP" -le 4294967295 ] 2>/dev/null; then
    O1=$(( (DECIMAL_IP >> 24) & 255 ))
    O2=$(( (DECIMAL_IP >> 16) & 255 ))
    O3=$(( (DECIMAL_IP >> 8) & 255 ))
    O4=$(( DECIMAL_IP & 255 ))
    HOST_LOWER="${O1}.${O2}.${O3}.${O4}"
  fi
fi

# Hex integer (e.g., 0x7f000001 = 127.0.0.1)
if [[ "$HOST_LOWER" =~ ^0x[0-9a-f]+$ ]]; then
  HEX_VAL=$(( HOST_LOWER ))
  if [ "$HEX_VAL" -ge 0 ] && [ "$HEX_VAL" -le 4294967295 ] 2>/dev/null; then
    O1=$(( (HEX_VAL >> 24) & 255 ))
    O2=$(( (HEX_VAL >> 16) & 255 ))
    O3=$(( (HEX_VAL >> 8) & 255 ))
    O4=$(( HEX_VAL & 255 ))
    HOST_LOWER="${O1}.${O2}.${O3}.${O4}"
  fi
fi

# Octal octets (e.g., 0177.0.0.1 = 127.0.0.1)
if [[ "$HOST_LOWER" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IFS='.' read -r A B C D <<< "$HOST_LOWER"
  octal_convert() {
    local val="$1"
    if [[ "$val" =~ ^0[0-9]+$ ]]; then
      printf '%d' "$(( 8#${val} ))" 2>/dev/null || echo "$val"
    else
      echo "$val"
    fi
  }
  A=$(octal_convert "$A")
  B=$(octal_convert "$B")
  C=$(octal_convert "$C")
  D=$(octal_convert "$D")
  HOST_LOWER="${A}.${B}.${C}.${D}"
fi

# =====================================================================
# PRIVATE / RESERVED IP RANGE CHECKS
# =====================================================================

if [[ "$HOST_LOWER" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IFS='.' read -r O1 O2 O3 O4 <<< "$HOST_LOWER"

  for octet in "$O1" "$O2" "$O3" "$O4"; do
    if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ] 2>/dev/null; then
      block "Invalid IP octet ($octet) in $HOST_LOWER."
    fi
  done

  [ "$O1" -eq 127 ] && block "Loopback range (127.0.0.0/8)."
  [ "$O1" -eq 10 ] && block "Private range (10.0.0.0/8)."
  [ "$O1" -eq 172 ] && [ "$O2" -ge 16 ] && [ "$O2" -le 31 ] && block "Private range (172.16.0.0/12)."
  [ "$O1" -eq 192 ] && [ "$O2" -eq 168 ] && block "Private range (192.168.0.0/16)."
  [ "$O1" -eq 169 ] && [ "$O2" -eq 254 ] && block "Link-local range (169.254.0.0/16)."
  [ "$O1" -eq 0 ] && block "Reserved range (0.0.0.0/8)."
  [ "$O1" -eq 100 ] && [ "$O2" -ge 64 ] && [ "$O2" -le 127 ] && block "Carrier-grade NAT range (100.64.0.0/10)."
  [ "$O1" -eq 192 ] && [ "$O2" -eq 0 ] && [ "$O3" -eq 0 ] && block "IETF protocol assignment range (192.0.0.0/24)."
  [ "$O1" -eq 192 ] && [ "$O2" -eq 0 ] && [ "$O3" -eq 2 ] && block "Documentation range (192.0.2.0/24 TEST-NET-1)."
  [ "$O1" -eq 198 ] && [ "$O2" -eq 51 ] && [ "$O3" -eq 100 ] && block "Documentation range (198.51.100.0/24 TEST-NET-2)."
  [ "$O1" -eq 203 ] && [ "$O2" -eq 0 ] && [ "$O3" -eq 113 ] && block "Documentation range (203.0.113.0/24 TEST-NET-3)."
  [ "$O1" -eq 198 ] && [ "$O2" -ge 18 ] && [ "$O2" -le 19 ] && block "Benchmarking range (198.18.0.0/15)."
  [ "$O1" -ge 240 ] && block "Reserved range (240.0.0.0/4)."
  [ "$O1" -eq 255 ] && [ "$O2" -eq 255 ] && [ "$O3" -eq 255 ] && [ "$O4" -eq 255 ] && block "Broadcast address (255.255.255.255)."
fi

# =====================================================================
# ALLOW
# =====================================================================
exit 0
```

---

*This hook was developed for use with Claude Code on Android/Termux but works on any platform where Claude Code runs.*
