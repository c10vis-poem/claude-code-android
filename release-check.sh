#!/usr/bin/env bash
# release-check.sh -- Mechanical pre-release sanity checks.
#
# Run from the repo root before any `gh release create` or `git push origin main`
# for a versioned release. Verifies the version is stamped consistently across
# every file that hardcodes it, and that no obvious release-hygiene issues remain.
#
# Usage:
#   bash release-check.sh
#
# Exit codes:
#   0 = all checks pass, safe to proceed.
#   1 = one or more checks failed; fix before releasing.

set -uo pipefail

FAILS=0
fail() { printf '[FAIL] %s\n' "$1" >&2; FAILS=$((FAILS+1)); }
ok()   { printf '[ok]   %s\n' "$1"; }

# Must run from repo root (where VERSION lives)
if [ ! -f VERSION ]; then
    fail "VERSION file missing at repo root. Run from the public repo root."
    exit 1
fi

# --- 1. VERSION file is semver ---
VERSION="$(tr -d '[:space:]' < VERSION)"
if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    fail "VERSION file content '$VERSION' is not semver (expected X.Y.Z)"
    exit 1
fi
ok "VERSION = $VERSION"

# --- 2. CHANGELOG top entry header matches VERSION ---
TOP_VER="$(grep -m1 '^## \[' CHANGELOG.md | sed -E 's/^## \[([^]]+)\].*/\1/' | tr -d '[:space:]')"
if [ "$TOP_VER" != "$VERSION" ]; then
    fail "CHANGELOG.md top entry is [$TOP_VER], expected [$VERSION]"
else
    ok "CHANGELOG.md top entry: [$VERSION]"
fi

# --- 3. README version badge shows VERSION ---
if grep -q "badge/Version-${VERSION}-" README.md; then
    ok "README.md version badge shows $VERSION"
else
    fail "README.md version badge does not show $VERSION"
fi

# --- 4. README CHANGELOG range row ends at VERSION ---
if grep -Eq "Version history from .* to ${VERSION}" README.md; then
    ok "README.md CHANGELOG range row ends at $VERSION"
else
    fail "README.md CHANGELOG range row does not end at $VERSION"
fi

# --- 5. SECURITY.md supported-versions table includes current MINOR.x as Yes ---
MAJOR_MINOR="$(printf '%s' "$VERSION" | sed -E 's/^([0-9]+\.[0-9]+)\..*$/\1/')"
if grep -Eq "^\|[[:space:]]+${MAJOR_MINOR}\.x[[:space:]]+\|[[:space:]]+Yes" .github/SECURITY.md; then
    ok ".github/SECURITY.md lists ${MAJOR_MINOR}.x as Supported = Yes"
else
    fail ".github/SECURITY.md does not list ${MAJOR_MINOR}.x with Supported = Yes"
fi

# --- 6. CHANGELOG [VERSION] Notes mentions backup tag ---
BACKUP_TAG="backup/pre-v${VERSION}"
if grep -qF "$BACKUP_TAG" CHANGELOG.md; then
    ok "CHANGELOG.md references $BACKUP_TAG"
else
    fail "CHANGELOG.md does not reference $BACKUP_TAG (the past-tense Notes claim must be true at push time)"
fi

# --- 7. No em dashes (U+2014) anywhere in tracked files ---
EMDASH_HITS="$(git ls-files | xargs grep -l $'\xe2\x80\x94' 2>/dev/null || true)"
if [ -n "$EMDASH_HITS" ]; then
    fail "em dash (U+2014) found in tracked files:"
    printf '%s\n' "$EMDASH_HITS" | sed 's/^/         /' >&2
else
    ok "no em dashes in tracked files"
fi

# --- 8. Current-version git tag does not yet exist ---
if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
    fail "tag v${VERSION} already exists locally -- release already published or aborted mid-push?"
else
    ok "tag v${VERSION} not yet created (created in release Phase 7)"
fi

# --- 9. Summary ---
echo ""
if [ "$FAILS" -eq 0 ]; then
    printf 'release-check.sh: PASS (all checks passed for v%s)\n' "$VERSION"
    exit 0
else
    printf 'release-check.sh: FAIL (%d check(s) failed for v%s)\n' "$FAILS" "$VERSION"
    exit 1
fi
