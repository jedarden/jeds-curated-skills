#!/usr/bin/env bash
# Extract and categorize all markdown headers from a plan file.
# Usage: scan-headers.sh <plan-file>
# Output: categorized header list with line numbers

set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: scan-headers.sh <plan-file>" >&2
  exit 1
fi

echo "=== Header Scan: $FILE ==="
echo ""

# All headers with line numbers
echo "--- All Headers ---"
grep -n "^#" "$FILE" || echo "(no headers found)"
echo ""

# Count by level
echo "--- Header Counts ---"
echo "H1 (# ): $(grep -c "^# " "$FILE" 2>/dev/null || echo 0)"
echo "H2 (## ): $(grep -c "^## " "$FILE" 2>/dev/null || echo 0)"
echo "H3 (### ): $(grep -c "^### " "$FILE" 2>/dev/null || echo 0)"
echo ""

# Check for key section presence (exit 0 regardless — just reporting)
echo "--- Key Section Presence ---"
check_section() {
  local label="$1"; shift
  local found=0
  for pattern in "$@"; do
    if grep -qi "$pattern" "$FILE" 2>/dev/null; then
      found=1; break
    fi
  done
  if [[ $found -eq 1 ]]; then
    echo "  PRESENT  $label"
  else
    echo "  MISSING  $label"
  fi
}

check_section "North Star / Mission"        "north star" "one.sentence mission" "mission"
check_section "Non-Goals"                   "non.goal" "non-goal" "not a goal" "out of scope"
check_section "Glossary"                    "glossary" "key term" "terminology"
check_section "Acceptance Scenarios"        "acceptance scenario" "pass criteria" "fail criteria"
check_section "Architecture Overview"       "architecture" "component" "system overview"
check_section "Data Model / Schema"         "data model" "schema" "table" "struct"
check_section "ADRs / Design Decisions"     "ADR" "decision record" "design decision"
check_section "Edge Case Catalog"           "edge case" "EC-"
check_section "Failure Modes"               "failure mode" "failure taxonomy" "resilience"
check_section "Anti-Patterns"               "anti-pattern" "what not to do" "pitfall"
check_section "Risk Register"               "risk register" "likelihood" "mitigation"
check_section "Rollback Plan"               "rollback" "roll back" "undo"
check_section "Phase Completion Criteria"   "completion criteria" "done when" "phase.*done"
check_section "Testing Strategy"            "testing strategy" "test plan" "unit test"
check_section "Performance Budget"          "performance budget" "p50" "p99" "latency.*ms"
check_section "Security / Threat Model"     "threat model" "security" "secrets"
check_section "Migration Plan"              "migration" "keep.*drop" "backward compat"
check_section "Deployment / Installation"   "deployment" "installation" "install"
check_section "Doctor / Health Check"       "doctor" "health check" "self.test"

echo ""
echo "--- File Stats ---"
echo "Total lines : $(wc -l < "$FILE")"
echo "Total words : $(wc -w < "$FILE")"
echo "Total chars : $(wc -c < "$FILE")"
