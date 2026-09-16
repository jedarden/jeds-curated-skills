#!/usr/bin/env bash
# Common utilities for skill scoring/scan scripts.
# Source this file at the top of your script:
#   source "$(dirname "$0")/../../lib/common.sh"
#
# Provides:
#   - check(): Pattern-matching check with pass/fail tracking
#   - print_score(): Standardized score output with status classification
#   - print_failures(): Print missing items in a formatted list
#   - count_headers(): Count markdown headers by level
#   - file_stats(): Print basic file statistics (lines, words, chars)

set -euo pipefail

# --- Pattern matching check with pass/fail tracking ---
# Usage: check "Label" "pattern1" "pattern2" ...
# Returns: None (updates global PASS, FAIL, FAILURES)
# Globals used: FILE (must be set), PASS, FAIL, FAILURES
check() {
  local label="$1"; shift
  local matched=0
  local pattern
  for pattern in "$@"; do
    if grep -qiE "$pattern" "$FILE" 2>/dev/null; then
      matched=1
      break
    fi
  done
  if [[ $matched -eq 1 ]]; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
    FAILURES+=("MISSING: $label")
  fi
}

# --- Print standardized score output with status ---
# Usage: print_score [custom_status_prefix]
# Arguments:
#   custom_status_prefix: Optional prefix for status line (default: "Status:")
# Globals used: FILE, PASS, FAIL
print_score() {
  local status_prefix="${1:-Status}"
  local total=$((PASS + FAIL))
  local pct=0
  [[ $total -gt 0 ]] && pct=$((PASS * 100 / total))

  echo "=== Score: $FILE ==="
  echo ""
  echo "Score: $PASS / $total ($pct%)"
  echo ""
  echo "$status_prefix:"
}

# --- Print failures/missing items ---
# Usage: print_failures [title]
# Arguments:
#   title: Optional title for the section (default: "--- Missing Checks ---")
# Globals used: FAILURES
print_failures() {
  local title="${1:--- Missing Checks ---}"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "$title"
    for f in "${FAILURES[@]}"; do
      echo "  $f"
    done
  fi
}

# --- Count markdown headers by level ---
# Usage: count_headers <file>
# Output: Prints counts for H1, H2, H3
count_headers() {
  local file="$1"
  echo "H1 (# ): $(grep -c "^# " "$file" 2>/dev/null || echo 0)"
  echo "H2 (## ): $(grep -c "^## " "$file" 2>/dev/null || echo 0)"
  echo "H3 (### ): $(grep -c "^### " "$file" 2>/dev/null || echo 0)"
}

# --- Print file statistics ---
# Usage: file_stats <file>
# Output: Prints total lines, words, and characters
file_stats() {
  local file="$1"
  echo "Total lines : $(wc -l < "$file")"
  echo "Total words : $(wc -w < "$file")"
  echo "Total chars : $(wc -c < "$file")"
}
