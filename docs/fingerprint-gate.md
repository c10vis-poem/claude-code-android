# Fingerprint Biometric Gate

Use your phone's fingerprint sensor to approve sensitive operations before they execute. A Claude Code hook calls `termux-fingerprint`, checks the result, and blocks the action if authentication fails.

---

## What It Does

The fingerprint gate adds a biometric confirmation step before destructive or high-impact operations:

- Pushing to public repositories
- Creating pull requests
- Force-pushing, resetting, or deleting branches
- Any other operation you define as sensitive

If the fingerprint check fails or is dismissed, the operation is blocked. Nothing runs until the device owner physically confirms it.

---

## Requirements

1. **Termux:API package.** Install in Termux:
   ```sh
   pkg install termux-api
   ```

2. **Termux:API companion app.** Install from F-Droid (search "Termux:API"). The package provides the CLI commands; the companion app provides the Android permissions bridge. Both are required. Without the companion app, `termux-fingerprint` fails silently.

3. **Source matching.** Termux and Termux:API must come from the same source (both F-Droid or both GitHub releases). Mixing sources causes signature mismatches and silent failures.

4. **A registered fingerprint** on the device (Settings > Security > Fingerprint).

> **Verify it works** before wiring it into hooks:
> ```sh
> termux-fingerprint
> ```
> Touch the sensor. A working setup returns JSON output containing `"auth_result": "AUTH_RESULT_SUCCESS"`.

---

## How It Works

`termux-fingerprint` prompts for biometric authentication via the Android system dialog. It returns JSON:

```json
{
  "auth_result": "AUTH_RESULT_SUCCESS"
}
```

On failure (wrong finger, dismissed, timeout):

```json
{
  "auth_result": "AUTH_RESULT_FAILURE",
  "errors": "..."
}
```

A helper function parses `auth_result` and returns exit code 0 (approved) or 1 (denied). Your hook script sources this function and calls it before allowing the sensitive operation to proceed.

---

## Setup

The gate script is also available as [`examples/fingerprint-gate.sh`](../examples/fingerprint-gate.sh) in this repository.

### Step 1: Create the gate function

Create a file that any hook can source. Put it wherever makes sense for your setup. `~/.claude/hooks/` is a natural choice if you keep your hooks there.

**`~/.claude/hooks/fingerprint-gate.sh`**

```sh
#!/usr/bin/env bash
# Fingerprint biometric gate. Source this file, then call require_fingerprint.

require_fingerprint() {
  if ! command -v termux-fingerprint >/dev/null 2>&1; then
    echo "termux-fingerprint not found. Install: pkg install termux-api" >&2
    echo "Also install the Termux:API companion app from F-Droid." >&2
    return 1
  fi

  local result
  result=$(termux-fingerprint)

  local auth_result
  auth_result=$(echo "$result" | jq -r '.auth_result // ""')

  if [ "$auth_result" = "AUTH_RESULT_SUCCESS" ]; then
    echo "Fingerprint verified." >&2
    return 0
  else
    echo "Fingerprint denied. Operation blocked." >&2
    return 1
  fi
}
```

> **Dependency:** This uses `jq` to parse JSON. Install it with `pkg install jq` if you don't have it.

### Step 2: Create a hook script

Create a hook that sources the gate and checks for sensitive operations. This example blocks `git push` to public repos and destructive git commands:

**`~/.claude/hooks/pre-tool-use-fingerprint-gate.sh`**

```sh
#!/usr/bin/env bash
# Block sensitive git operations without fingerprint approval

# Source the gate function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fingerprint-gate.sh"

# Read the JSON payload Claude Code sends on stdin
INPUT=$(cat)

# Extract tool name and command from JSON
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only gate Bash tool calls
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Check for sensitive git operations
case "$COMMAND" in
  *"git push"*|*"git push --force"*|*"git reset --hard"*|*"git branch -D"*|*"gh pr create"*)
    echo "Sensitive operation detected: requesting fingerprint approval..." >&2
    if require_fingerprint; then
      exit 0  # Approved
    else
      echo '{"decision": "block", "reason": "Fingerprint authentication failed. Operation blocked."}'
      exit 0
    fi
    ;;
  *)
    exit 0  # Not a sensitive operation, allow it
    ;;
esac
```

Make it executable:

```sh
chmod +x ~/.claude/hooks/fingerprint-gate.sh
chmod +x ~/.claude/hooks/pre-tool-use-fingerprint-gate.sh
```

> **Bypass vectors to be aware of:** The `case "$COMMAND"` pattern matching above operates on the raw command string and is illustrative rather than airtight. Predictable ways for a malicious or careless prompt to slip past it:
> - **Variable interpolation:** `cmd="git push"; $cmd`: the raw command contains the variable assignment, not the literal substring `"git push"`, so the case pattern doesn't fire.
> - **Subshell expansion:** `$(echo git push)`: the raw command contains the subshell expression, not the resulting command.
> - **Whitespace tricks:** `git$'\t'push` or `git  push` (double space): glob `*"git push"*` requires the exact single-space substring.
> - **Aliased forms:** `gp` (shell alias for `git push`), or any user-defined script that calls git push.
>
> If your threat model includes a prompt-injection attacker who knows how this hook is wired, build the check on a parsed view of the command. Two safer shapes:
> - Tokenize `$COMMAND` with `set --` and inspect `$1`/`$2` against an allowlist.
> - Configure git itself to require a credential helper that triggers the fingerprint prompt. This moves the gate inside git, where command-line tricks don't help.
>
> The example here is good for "I want a fingerprint nag before destructive operations during normal use." It is not a security boundary against an adversary who can run arbitrary shell from inside a Claude Code session.

### Step 3: Register the hook in Claude Code settings

Add the hook to your Claude Code settings so it runs before tool use:

**`~/.claude/settings.json`**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hook": "~/.claude/hooks/pre-tool-use-fingerprint-gate.sh"
      }
    ]
  }
}
```

The `matcher` field controls which tool triggers the hook. Setting it to `"Bash"` means the hook only fires for shell commands. You can also use `"*"` to fire on every tool call, or name a specific tool like `"Write"`.

---

## Customizing the Gate

### Gate different operations

Modify the `case` statement in the hook script to match whatever commands you consider sensitive. Some ideas:

```sh
*"rm -rf"*)       # Recursive deletion
*"git rebase"*)   # History rewriting
*"npm publish"*)  # Package publishing
*"gh release"*)   # GitHub releases
```

### Gate only public repos

Check the remote URL before requiring fingerprint:

```sh
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
case "$REMOTE_URL" in
  *"github.com"*)
    # Public repo. Require fingerprint.
    require_fingerprint || exit 1
    ;;
  *)
    # Private or no remote. Allow.
    ;;
esac
```

### Multiple hooks

You can register multiple hooks for the same event. Claude Code runs them in order; if any hook blocks, the operation stops:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hook": "~/.claude/hooks/pre-tool-use-fingerprint-gate.sh"
      },
      {
        "matcher": "Write",
        "hook": "~/.claude/hooks/pre-tool-use-file-safety.sh"
      }
    ]
  }
}
```

---

## Troubleshooting

**`termux-fingerprint: command not found`**
```sh
pkg install termux-api
```
Then install the Termux:API companion app from F-Droid.

**Fingerprint prompt never appears**
The Termux:API companion app is missing or was installed from a different source than Termux. Uninstall both, reinstall both from F-Droid.

**`jq: command not found`**
```sh
pkg install jq
```

**Hook doesn't fire**
Check that `settings.json` is valid JSON and the hook path is correct. Test the hook directly:
```sh
echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' \
  | bash ~/.claude/hooks/pre-tool-use-fingerprint-gate.sh
```

**Fingerprint works in terminal but not in hooks**
Hooks run in a subprocess. The `termux-fingerprint` binary needs to be on PATH in that context. Try using the full path: `/data/data/com.termux/files/usr/bin/termux-fingerprint`.

---

## Security Notes

- The fingerprint check runs locally on your device. No biometric data leaves the phone.
- `termux-fingerprint` uses Android's BiometricPrompt API, the same system used by banking apps and password managers.
- The gate is only as strong as your hook configuration. If a command can bypass the hook (e.g., by not matching the `case` pattern), it won't be gated.
- This is a speed bump for autonomous AI operations, not a security boundary. A determined attacker with device access has other vectors. Its purpose is ensuring the device owner approves consequential actions before they happen.

---

*Last updated: 2026-05-29.*
