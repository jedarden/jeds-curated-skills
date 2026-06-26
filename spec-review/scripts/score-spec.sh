#!/usr/bin/env bash
# Quick automated scoring of a spec against the core review criteria.
# Usage: score-spec.sh <spec-file>
# Returns: score percentage, presence checks, and detected ambiguity smells.

set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: score-spec.sh <spec-file>" >&2
  exit 1
fi

PASS=0
FAIL=0
FAILURES=()

# A check passes if ANY of its patterns is present (case-insensitive).
check() {
  local label="$1"; shift
  local matched=0
  for pattern in "$@"; do
    if grep -qiE "$pattern" "$FILE" 2>/dev/null; then
      matched=1; break
    fi
  done
  if [[ $matched -eq 1 ]]; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
    FAILURES+=("MISSING: $label")
  fi
}

# Presence of structure that a plannable spec needs.
check "Acceptance criteria"      "acceptance crit" "acceptance scenario" "given.*when.*then" "passes when" "pass/fail"
check "Success metrics"          "success metric" "kpi" "p50|p95|p99" "latency" "throughput" "target.*ms"
check "Non-goals / out of scope" "non.?goal" "out of scope" "not in scope" "explicitly excluded"
check "Performance NFR"          "performance" "latency" "throughput" "response time" "load"
check "Security NFR"             "security" "auth(entication|orization)" "permission" "encrypt" "secret"
check "Scale / capacity"         "scale" "capacity" "concurrent" "volume" "growth"
check "Error / edge states"      "error" "edge case" "invalid input" "failure" "timeout" "empty state"
check "Data lifecycle"           "retention" "deletion" "data lifecycle" "migration" "export"
check "Roles / permissions"      "role" "permission" "rbac" "authorized" "admin"
check "Assumptions"              "assumption" "assume" "we assume"
check "Dependencies"             "dependenc" "depends on" "third.party" "external service"
check "Open questions"           "open question" "tbd" "to be decided" "unresolved" "needs decision"
check "Constraints"              "constraint" "deadline" "budget" "compliance" "regulat" "limit"

echo "=== Spec Score: $FILE ==="
echo ""

TOTAL=$((PASS + FAIL))
PCT=$(( PASS * 100 / TOTAL ))
echo "Structure score: $PASS / $TOTAL ($PCT%)"
echo ""

if [[ $PCT -ge 80 ]]; then
  echo "Status: READY FOR PLANNING (minor gaps only)"
elif [[ $PCT -ge 40 ]]; then
  echo "Status: NEEDS TIGHTENING (run the full review)"
else
  echo "Status: NOT READY (fundamental gaps — fix before a full review is worthwhile)"
fi

echo ""
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "--- Missing Structure ---"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
  echo ""
fi

# Ambiguity smell scan — count vague terms (a high count signals clarity defects).
echo "--- Ambiguity Smells (count of vague terms) ---"
SMELL_TOTAL=0
for term in "fast" "slow" "quick" "soon" "large" "small" "some" "many" "most" "few" \
            "several" "etc" "and so on" "user.?friendly" "intuitive" "seamless" "robust" \
            "performant" "scalable" "as appropriate" "if needed" "where possible" \
            "works well" "handle.*gracefully"; do
  n=$( { grep -oiE "$term" "$FILE" 2>/dev/null || true; } | wc -l | tr -d ' ')
  if [[ "$n" -gt 0 ]]; then
    printf "  %-22s %s\n" "$term" "$n"
    SMELL_TOTAL=$((SMELL_TOTAL + n))
  fi
done
echo ""
echo "Total ambiguity smells: $SMELL_TOTAL (each should be quoted and rewritten in the review)"
