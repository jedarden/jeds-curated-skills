#!/usr/bin/env bash
# Inventory a test suite: count test functions per file, detect frameworks, and
# report source directories that have NO corresponding tests.
# Usage: scan-tests.sh <repo-or-tests-dir>

set -euo pipefail

ROOT="${1:-}"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "Usage: scan-tests.sh <repo-or-tests-dir>" >&2
  exit 1
fi

ROOT="${ROOT%/}"

# Directories never worth scanning.
PRUNE='-name .git -o -name node_modules -o -name target -o -name dist -o -name build -o -name .venv -o -name venv -o -name __pycache__ -o -name vendor'

is_test_file() {
  case "$1" in
    *_test.go|*_test.py|*_test.rb|*_test.exs|*_test.ts|*_test.js) return 0 ;;
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.ts|*.spec.js) return 0 ;;
    *test_*.py|*_spec.rb) return 0 ;;
    *Test.java|*Tests.cs|*_spec.lua) return 0 ;;
  esac
  case "$1" in
    */tests/*|*/test/*|*/__tests__/*|*/spec/*) return 0 ;;
  esac
  return 1
}

# Count test functions in a file across common frameworks.
count_tests() {
  local f="$1"
  grep -cE \
    -e '^[[:space:]]*def test_' \
    -e '\b(it|test|describe)[[:space:]]*\(' \
    -e '^[[:space:]]*#\[test\]' \
    -e '^[[:space:]]*#\[tokio::test\]' \
    -e '^[[:space:]]*func Test[A-Z]' \
    -e '@Test\b' \
    -e '\bt\.Run\(' \
    "$f" 2>/dev/null || true
}

echo "=== Test Inventory: $ROOT ==="
echo ""

# --- Collect test files ---
TEST_FILES=()
while IFS= read -r f; do
  if is_test_file "$f"; then
    TEST_FILES+=("$f")
  fi
done < <(find "$ROOT" \( $PRUNE \) -prune -o -type f -print 2>/dev/null)

TOTAL_FILES=${#TEST_FILES[@]}
TOTAL_TESTS=0

echo "--- Test files (test-function count) ---"
if [[ $TOTAL_FILES -eq 0 ]]; then
  echo "  (none found)"
else
  for f in "${TEST_FILES[@]}"; do
    n=$(count_tests "$f")
    TOTAL_TESTS=$((TOTAL_TESTS + n))
    printf '  %4d  %s\n' "$n" "${f#$ROOT/}"
  done
fi
echo ""
echo "Files: $TOTAL_FILES    Test functions: $TOTAL_TESTS"
echo ""

# --- Framework detection ---
echo "--- Detected frameworks ---"
detect() { grep -rqlE "$2" "$ROOT" --include="$3" 2>/dev/null && echo "  - $1"; return 0; }
{
  detect "pytest / unittest (Python)" 'def test_|import pytest|unittest' '*.py'
  detect "jest / mocha / vitest (JS/TS)" '\b(it|test|describe)\(' '*.[jt]s'
  detect "cargo test (Rust)" '#\[test\]|#\[tokio::test\]' '*.rs'
  detect "go test (Go)" 'func Test[A-Z]' '*.go'
  detect "rspec (Ruby)" '\bdescribe\b|\bit\b' '*.rb'
  detect "JUnit (Java)" '@Test' '*.java'
} | sort -u || true
echo ""

# --- Source dirs with NO tests ---
# A "source dir" = a directory containing non-test source files. Flag any whose
# subtree contains zero test files.
echo "--- Source directories with NO corresponding tests ---"
SRC_DIRS=$(find "$ROOT" \( $PRUNE \) -prune -o -type f \
  \( -name '*.py' -o -name '*.rs' -o -name '*.go' -o -name '*.ts' \
     -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.rb' \
     -o -name '*.java' \) -print 2>/dev/null \
  | while IFS= read -r f; do is_test_file "$f" || dirname "$f"; done \
  | sort -u)

UNTESTED=0
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  # Does this directory's subtree contain any test file?
  has_test=0
  while IFS= read -r tf; do
    if is_test_file "$tf"; then has_test=1; break; fi
  done < <(find "$d" -maxdepth 1 -type f -print 2>/dev/null)
  if [[ $has_test -eq 0 ]]; then
    echo "  ${d#$ROOT/}"
    UNTESTED=$((UNTESTED + 1))
  fi
done <<< "$SRC_DIRS"

if [[ $UNTESTED -eq 0 ]]; then
  echo "  (every source directory has at least one co-located test file)"
fi
echo ""
echo "Source dirs lacking co-located tests: $UNTESTED"
echo ""
echo "NOTE: co-located check is heuristic — tests may live in a parallel tests/ tree."
echo "Treat flagged dirs as coverage SUSPECTS to confirm during review, not proof."
