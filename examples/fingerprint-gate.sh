#!/usr/bin/env bash
set -euo pipefail

# Fingerprint biometric gate -- source this file, then call require_fingerprint
#
# Usage:
#   source fingerprint-gate.sh
#   require_fingerprint || exit 1
#
# The write_sentinel function is optional -- use it to cache approval
# for a time window so the user is not prompted on every operation.

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

# Optional: write a sentinel file after successful authentication.
# Other hooks can check this file to skip re-prompting within a window.
#
# Usage:
#   require_fingerprint && write_sentinel "/tmp/fp-approved"
#
# Then in another hook:
#   if [ -f "/tmp/fp-approved" ] && [ "$(find /tmp/fp-approved -mmin -5)" ]; then
#     echo "Recently approved, skipping fingerprint." >&2
#   else
#     require_fingerprint || exit 1
#   fi
write_sentinel() {
  local sentinel_path="${1:?Usage: write_sentinel <path>}"
  touch "$sentinel_path"
}
