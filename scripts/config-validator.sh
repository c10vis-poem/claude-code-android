#!/usr/bin/env bash
# config-validator.sh: Validate the .claude/ directory of a Claude Code
#                      repo for internal consistency.
#
# Checks agent definitions, skill files, hook registrations, settings.json
# JSON validity, cross-references between them, and naming conventions.
# Designed to run during repo audits or after adding new agents, skills,
# or hooks. Non-destructive; read-only.
#
# Usage:
#   bash scripts/config-validator.sh [path-to-repo-root]
#
# If no path is given, the current working directory is used.
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more FAIL items
#   2 = the .claude/ directory does not exist at the target path

set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

if [ ! -d .claude ]; then
  echo "ERROR: no .claude/ directory at $(pwd)" >&2
  exit 2
fi

FAILS=0
WARNS=0
report() {
  printf '%-12s | %-40s | %-6s | %s\n' "$1" "$2" "$3" "$4"
  case "$3" in
    FAIL) FAILS=$((FAILS+1)) ;;
    WARN) WARNS=$((WARNS+1)) ;;
  esac
}

printf '%-12s | %-40s | %-6s | %s\n' Component Check Status Detail
printf '%-12s-+-%-40s-+-%-6s-+-%s\n' '------------' '----------------------------------------' '------' '--------------------------------'

# --- 1. Agent files ---

if [ -d .claude/agents ]; then
  for f in .claude/agents/*.md; do
    [ -f "$f" ] || continue
    fname="$(basename "$f" .md)"
    fm_name="$(awk '/^name:/ {print $2; exit}' "$f" 2>/dev/null || true)"
    fm_desc="$(awk '/^description:/ {print; exit}' "$f" 2>/dev/null || true)"
    if [ -z "$fm_name" ] || [ -z "$fm_desc" ]; then
      report "agents/$fname.md" "frontmatter name+description present" FAIL "missing one or both"
    elif [ "$fm_name" != "$fname" ]; then
      report "agents/$fname.md" "name matches filename" FAIL "frontmatter says '$fm_name'"
    else
      report "agents/$fname.md" "frontmatter complete + name matches" PASS ""
    fi
  done
else
  report ".claude/agents/" "directory exists" WARN "not present (OK if no agents shipped)"
fi

# --- 2. Skill files ---

if [ -d .claude/skills ]; then
  for d in .claude/skills/*/; do
    [ -d "$d" ] || continue
    skill="$(basename "$d")"
    if [ ! -f "$d/SKILL.md" ]; then
      report "skills/$skill" "SKILL.md present" FAIL "directory exists, no SKILL.md"
      continue
    fi
    fm_name="$(awk '/^name:/ {print $2; exit}' "$d/SKILL.md" 2>/dev/null || true)"
    if [ "$fm_name" != "$skill" ]; then
      report "skills/$skill" "name matches dir" FAIL "frontmatter says '$fm_name'"
    else
      report "skills/$skill" "SKILL.md + name match" PASS ""
    fi
  done
else
  report ".claude/skills/" "directory exists" WARN "not present (OK if no skills shipped)"
fi

# --- 3. settings.json ---

if [ -f .claude/settings.json ]; then
  if command -v jq >/dev/null 2>&1; then
    if jq -e . .claude/settings.json >/dev/null 2>&1; then
      report "settings.json" "valid JSON" PASS ""
    else
      report "settings.json" "valid JSON" FAIL "jq parse failed"
    fi
    # Hook command existence. In the Claude Code schema, hooks live under
    # .hooks.<Event>[].hooks[].command (the executable field is "command",
    # nested one level below the matcher group), so walk down to .command.
    HOOKS=$(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' .claude/settings.json 2>/dev/null || true)
    while IFS= read -r hook; do
      [ -n "$hook" ] || continue
      # Resolve ~/.claude/... if present (this check is per-repo, not user-global)
      hook_path="${hook/#\~/$HOME}"
      if [ -f "$hook_path" ] || [ -f "./$hook" ]; then
        report "settings.json" "hook script: $hook" PASS "found"
      else
        report "settings.json" "hook script: $hook" WARN "not found at expected path"
      fi
    done <<< "$HOOKS"
  else
    report "settings.json" "valid JSON" WARN "jq not installed; cannot validate"
  fi
else
  report ".claude/settings.json" "file exists" WARN "not present (OK if no hooks registered)"
fi

# --- 4. Cross-references ---

# Agents referencing skills
if [ -d .claude/agents ] && [ -d .claude/skills ]; then
  for f in .claude/agents/*.md; do
    [ -f "$f" ] || continue
    refs=$(awk '/^skills:/,/^[a-z]/{print}' "$f" 2>/dev/null | grep -oE '\b[a-z][a-z0-9-]+\b' | grep -v '^skills$' || true)
    for r in $refs; do
      if [ ! -d ".claude/skills/$r" ]; then
        report "agents/$(basename "$f" .md)" "referenced skill exists" FAIL "no .claude/skills/$r/"
      fi
    done
  done
fi

# --- 5. Naming consistency ---

NON_KEBAB=$(find .claude -type d -name '*[A-Z_]*' 2>/dev/null | head -5 || true)
if [ -n "$NON_KEBAB" ]; then
  report ".claude/*" "directory names kebab-case" WARN "non-kebab dirs found"
  echo "$NON_KEBAB" | sed 's/^/             /'
else
  report ".claude/*" "directory names kebab-case" PASS ""
fi

# --- Summary ---

echo ""
echo "Summary: $FAILS FAIL, $WARNS WARN"
if [ "$FAILS" -gt 0 ]; then
  echo "Resolve the FAIL items above. WARN items are advisory."
  exit 1
fi
echo "OK"
exit 0
