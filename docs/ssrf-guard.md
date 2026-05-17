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

The canonical script lives at [`examples/ssrf-guard.sh`](../examples/ssrf-guard.sh) in this repository. Copy or download it into your Claude Code hooks directory.

### 1. Install the script

```bash
mkdir -p ~/.claude/hooks

# If you have the repo cloned:
cp examples/ssrf-guard.sh ~/.claude/hooks/ssrf-guard.sh

# Or download directly:
curl -fsSL https://raw.githubusercontent.com/ferrumclaudepilgrim/claude-code-android/main/examples/ssrf-guard.sh \
  -o ~/.claude/hooks/ssrf-guard.sh

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

See [`examples/ssrf-guard.sh`](../examples/ssrf-guard.sh) for the canonical implementation. This doc and the example are kept in sync intentionally -- the example is the single source of truth.

---

*This hook was developed for use with Claude Code on Android/Termux but works on any platform where Claude Code runs.*
