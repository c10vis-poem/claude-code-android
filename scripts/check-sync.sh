#!/usr/bin/env bash
# check-sync.sh: Verify the sections that install.sh and migrate.sh must keep
#               byte-identical have not drifted apart.
#
# install.sh and migrate.sh independently implement the same npm-version
# resolve/download/checksum/patchelf logic and emit the same wrapper script,
# because migrate.sh mirrors install.sh instead of sourcing it. Both files
# mark the shared sections with matching "# SYNC:BEGIN <name>" / "# SYNC:END
# <name>" comments; this script extracts each named block from both files
# and diffs them. Run it after editing either script, and it also runs in CI.
#
# Usage:
#   bash scripts/check-sync.sh

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
A="$here/install.sh"
B="$here/migrate.sh"

extract_names() {
  grep -oE '# SYNC:BEGIN [A-Za-z0-9_-]+' "$1" | awk '{print $3}'
}

extract_block() {
  # extract_block FILE NAME
  awk -v name="$2" '
    $0 ~ "# SYNC:BEGIN " name { f=1; next }
    $0 ~ "# SYNC:END " name   { f=0 }
    f { print }
  ' "$1"
}

names_a="$(extract_names "$A" | sort -u)"
names_b="$(extract_names "$B" | sort -u)"

if [ "$names_a" != "$names_b" ]; then
  echo "[fail] SYNC block names differ between $(basename "$A") and $(basename "$B")" >&2
  echo "  $(basename "$A"): $(echo "$names_a" | tr '\n' ' ')" >&2
  echo "  $(basename "$B"): $(echo "$names_b" | tr '\n' ' ')" >&2
  exit 1
fi

if [ -z "$names_a" ]; then
  echo "[fail] no SYNC:BEGIN/END markers found in $(basename "$A")" >&2
  exit 1
fi

fail=0
while IFS= read -r name; do
  [ -z "$name" ] && continue
  block_a="$(extract_block "$A" "$name")"
  block_b="$(extract_block "$B" "$name")"
  if [ "$block_a" != "$block_b" ]; then
    echo "[fail] SYNC block '$name' has drifted between $(basename "$A") and $(basename "$B"):" >&2
    diff <(printf '%s\n' "$block_a") <(printf '%s\n' "$block_b") >&2 || true
    fail=1
  else
    echo "[ok] SYNC block '$name' matches"
  fi
done <<< "$names_a"

exit "$fail"
