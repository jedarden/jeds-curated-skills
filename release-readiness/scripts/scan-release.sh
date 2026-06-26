#!/usr/bin/env bash
# Gather raw release facts from a git repository: the range since the last release,
# changed files, uncommitted changes, changelog/version/CI presence, and leftover
# debug/TODO/FIXME markers in changed files.
# Usage: scan-release.sh [target-ref]
#   target-ref defaults to HEAD.

set -euo pipefail

TARGET="${1:-HEAD}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Usage: scan-release.sh [target-ref]   (must be run inside a git repository)" >&2
  exit 1
fi

echo "=== Release Scan ==="
echo ""

# --- Last release tag ---
LAST_TAG="$(git describe --tags --abbrev=0 "${TARGET}^" 2>/dev/null || git describe --tags --abbrev=0 2>/dev/null || true)"
if [[ -z "$LAST_TAG" ]]; then
  echo "Last release tag: (none found — treating as first release)"
  RANGE="$TARGET"
else
  echo "Last release tag: $LAST_TAG"
  RANGE="${LAST_TAG}..${TARGET}"
fi
echo "Range: $RANGE"
echo ""

# --- Commits since last release ---
COMMIT_COUNT="$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)"
echo "Commits since last release: $COMMIT_COUNT"
echo "--- recent commit subjects ---"
git log --no-merges --pretty='  %h %s' "$RANGE" 2>/dev/null | head -30 || true
echo ""

# --- Changed files ---
if [[ -n "$LAST_TAG" ]]; then
  CHANGED_FILES="$(git diff --name-only "$LAST_TAG" "$TARGET" 2>/dev/null || true)"
else
  CHANGED_FILES="$(git ls-files 2>/dev/null || true)"
fi
CHANGED_COUNT="$(printf '%s\n' "$CHANGED_FILES" | grep -c . || true)"
echo "Changed files: $CHANGED_COUNT"
printf '%s\n' "$CHANGED_FILES" | sed 's/^/  /' | head -60
echo ""

# --- Working tree status ---
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo "Working tree: DIRTY (uncommitted changes present)"
  git status --porcelain 2>/dev/null | sed 's/^/  /' | head -30
else
  echo "Working tree: clean"
fi
echo ""

# --- Changelog detection ---
echo "--- Changelog ---"
CHANGELOG="$(git ls-files 2>/dev/null | grep -iE '(^|/)(change(log|s)|history|release[-_ ]?notes)[^/]*$' | head -5 || true)"
if [[ -n "$CHANGELOG" ]]; then
  printf '%s\n' "$CHANGELOG" | sed 's/^/  found: /'
else
  echo "  NONE FOUND"
fi
echo ""

# --- Version file detection ---
echo "--- Version files ---"
VERSION_FILES="$(git ls-files 2>/dev/null | grep -iE '(^|/)(Cargo\.toml|package\.json|pyproject\.toml|setup\.py|setup\.cfg|version\.txt|VERSION|__version__\.py|build\.gradle|pom\.xml|go\.mod|\.csproj)$' | head -10 || true)"
if [[ -n "$VERSION_FILES" ]]; then
  printf '%s\n' "$VERSION_FILES" | sed 's/^/  found: /'
else
  echo "  NONE FOUND"
fi
echo ""

# --- Lockfile detection ---
echo "--- Lockfiles ---"
LOCKFILES="$(git ls-files 2>/dev/null | grep -iE '(^|/)(Cargo\.lock|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|Pipfile\.lock|go\.sum|composer\.lock|Gemfile\.lock)$' | head -10 || true)"
if [[ -n "$LOCKFILES" ]]; then
  printf '%s\n' "$LOCKFILES" | sed 's/^/  found: /'
else
  echo "  NONE FOUND (dependencies may not be pinned)"
fi
echo ""

# --- CI config detection ---
echo "--- CI config ---"
CI_FILES="$(git ls-files 2>/dev/null | grep -iE '(^\.github/workflows/|^\.gitlab-ci\.yml$|^\.circleci/|(^|/)(Jenkinsfile|\.drone\.yml|azure-pipelines\.yml|\.woodpecker\.yml|\.forgejo/|\.gitea/))' | head -10 || true)"
if [[ -n "$CI_FILES" ]]; then
  printf '%s\n' "$CI_FILES" | sed 's/^/  found: /'
else
  echo "  NONE FOUND"
fi
echo ""

# --- Leftover markers in changed files ---
echo "--- Leftover TODO / FIXME / debug markers in changed files ---"
MARKER_HITS=0
if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    case "$f" in
      *test*|*spec*|*fixture*|*/testdata/*|*.md|*CHANGELOG*) continue ;;
    esac
    if hits="$(grep -nIE 'TODO|FIXME|XXX|HACK|console\.log|println!\("?DEBUG|debugger;|binding\.pry|import pdb|breakpoint\(\)' "$f" 2>/dev/null)"; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        echo "  $f:$line"
        MARKER_HITS=$((MARKER_HITS + 1))
      done <<< "$hits"
    fi
  done <<< "$CHANGED_FILES"
fi
if [[ "$MARKER_HITS" -eq 0 ]]; then
  echo "  none found in shipped paths"
else
  echo "  ($MARKER_HITS marker(s) found — review before release)"
fi
echo ""

echo "=== End Scan ==="
