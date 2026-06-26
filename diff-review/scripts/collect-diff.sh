#!/usr/bin/env bash
# Collect a unified diff for review and a changed-files summary.
# Usage: collect-diff.sh [base-ref]
#
# Resolution order when no base-ref is given:
#   1. merge-base of HEAD with the default branch (origin/HEAD, then main, then master)
#   2. staged changes (git diff --cached)
#   3. working-tree changes (git diff)
# Output: a labeled summary block, then the unified diff on stdout.

set -euo pipefail

BASE_REF="${1:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a git work tree." >&2
  exit 1
fi

# Resolve a branch ref to a commit if it exists; print the sha, else nothing.
resolve_ref() {
  local ref="$1"
  git rev-parse --verify --quiet "$ref" 2>/dev/null || true
}

MODE=""
RANGE=""

if [[ -n "$BASE_REF" ]]; then
  BASE_SHA="$(resolve_ref "$BASE_REF")"
  if [[ -z "$BASE_SHA" ]]; then
    echo "Error: base ref '$BASE_REF' not found." >&2
    exit 1
  fi
  MB="$(git merge-base "$BASE_SHA" HEAD 2>/dev/null || echo "$BASE_SHA")"
  MODE="explicit base ($BASE_REF)"
  RANGE="$MB"
else
  # Try default-branch candidates in order.
  DEFAULT=""
  for cand in origin/HEAD origin/main origin/master main master; do
    if [[ "$cand" == "origin/HEAD" ]]; then
      sha="$(git rev-parse --verify --quiet origin/HEAD 2>/dev/null || true)"
    else
      sha="$(resolve_ref "$cand")"
    fi
    if [[ -n "$sha" ]]; then DEFAULT="$cand"; break; fi
  done

  if [[ -n "$DEFAULT" ]]; then
    MB="$(git merge-base "$DEFAULT" HEAD 2>/dev/null || true)"
    if [[ -n "$MB" ]] && [[ "$MB" != "$(git rev-parse HEAD)" ]]; then
      MODE="merge-base with $DEFAULT"
      RANGE="$MB"
    fi
  fi

  # Fall back to staged, then working tree.
  if [[ -z "$RANGE" ]]; then
    if ! git diff --cached --quiet 2>/dev/null; then
      MODE="staged changes"
    else
      MODE="working-tree changes"
    fi
  fi
fi

echo "=== Diff Review: collection ==="
echo "Mode : ${MODE}"

if [[ -n "$RANGE" ]]; then
  echo "Base : ${RANGE}"
  echo "Head : $(git rev-parse HEAD)"
  echo ""
  echo "--- Changed Files (summary) ---"
  git diff --stat "$RANGE" HEAD || true
  echo ""
  echo "--- Unified Diff ---"
  git diff "$RANGE" HEAD
elif [[ "$MODE" == "staged changes" ]]; then
  echo ""
  echo "--- Changed Files (summary) ---"
  git diff --cached --stat || true
  echo ""
  echo "--- Unified Diff ---"
  git diff --cached
else
  echo ""
  echo "--- Changed Files (summary) ---"
  git diff --stat || true
  echo ""
  echo "--- Unified Diff ---"
  git diff
fi
