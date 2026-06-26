#!/usr/bin/env bash
# Self-score a generated plan against the completeness bar.
# Usage: score-draft.sh <plan-file>
# Returns: completeness percentage and the list of sections still MISSING.
# Mirrors CHECKLIST-COMPLETENESS.md so the author skill knows what to backfill.

set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: score-draft.sh <plan-file>" >&2
  exit 1
fi

PASS=0
FAIL=0
FAILURES=()

check() {
  local label="$1"; shift
  local matched=0
  local pattern
  for pattern in "$@"; do
    if grep -qiE "$pattern" "$FILE" 2>/dev/null; then
      matched=1; break
    fi
  done
  if [[ $matched -eq 1 ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("MISSING: $label")
  fi
}

# 1. Scope lock
check "1.1 North Star"               "north star" "one.sentence" "success is when"
check "1.2 Non-Goals + rationale"    "non.?goal" "out of scope" "explicit scope boundaries"
check "1.3 Hard Requirements"        "hard requirement" "non.?negotiable" "must not" "forbidden"
check "1.4 Glossary"                 "glossary" "key term" "terminology"
check "1.5 Normative Language"       "normative language" "rfc 2119" "rfc.2119"

# 2. Acceptance
check "2.1 Acceptance Scenarios"     "acceptance scenario" "scenario [0-9]"
check "2.2 Pass/Fail criteria"       "pass:" "fail:" "pass criteria" "fail criteria"
check "2.3 Error/recovery scenario"  "unreachable" "degraded" "recovery" "interrupted" "mid-sync"

# 3. Architecture
check "3.1 Component overview"       "component overview" "component model" "architecture"
check "3.2 Data flow"                "data flow" "end.to.end" "traced"
check "3.3 Concurrency model"        "concurrency" "execution model" "single.writer" "async" "thread"
check "3.4 Technology decisions"     "why .* over" "technology decision" "chosen" "not a flat"

# 4. Data model
check "4.1 Core entities"            "core entit" "core data model" "schema" "struct |table"
check "4.2 Source of truth"          "source of truth" "authoritative" "storage" "retention"

# 5. Pre-flight safety
check "5.1 Edge case catalog"        "edge case" "EC-[0-9]"
check "5.2 Failure modes/recovery"   "failure mode" "failure.*recovery" "recovery"
check "5.3 Invariants"               "invariant" "must always hold" "always hold"
check "5.4 Rollback"                 "rollback" "roll back" "undone" "state.*capture"

# 6. Phasing
check "6.1 Walking skeleton"         "walking skeleton" "phase 0"
check "6.2 Phases named"             "phase [0-9]" "phase 1" "### phase"
check "6.3 Completion criteria"      "completion criteria" "does not include" "exit criteria"

# 7. Testing
check "7.1 Test levels"              "unit" "integration" "testing strategy" "test level"
check "7.2 Quality gates"            "quality gate" "stop.ship" "definition of done"

# 8. Security
check "8.1 Threat model"             "threat model" "threat" "attack" "trivial because"
check "8.2 Secrets handling"         "secret" "credential" "api key" "never log"

# 9. Performance
check "9.1 Performance budget"       "performance budget" "p50" "p99" "latency" "throughput" "non-budget"
check "9.2 Measurement method"       "how measured" "measured" "benchmark" "reference condition"

# 10. Operations
check "10.1 Deployment & config"     "deployment" "install" "config" "non.?interactive" "ci mode"
check "10.2 Migration/compat"        "migration" "backward compat" "keep / drop" "keep/drop" "reinterpret" "n/a .* greenfield"
check "10.3 Monitoring/health"       "monitoring" "health" "doctor" "health.?check"

# 11. API / interface
check "11.1 Interface surface"       "interface" "api" "endpoint" "command" "signature"
check "11.2 Error contract"          "error contract" "exit code" "error.*surfaced" "fail"

# 12. Risk
check "12.1 Risk register"           "risk register" "likelihood" "r1 " "\| r[0-9]"
check "12.2 Plan B"                  "plan b" "fallback" "if .* proves false" "alternative approach"

# 13. Hygiene
check "13.1 Open Questions"          "open question" "resolve by" "owner:"
check "13.2 Revision history"        "revision history" "last updated" "initial draft"

TOTAL=$((PASS + FAIL))
PCT=$(( PASS * 100 / TOTAL ))

echo "=== Completeness Score: $FILE ==="
echo ""
echo "Score: $PASS / $TOTAL ($PCT%)"
echo ""

if [[ $PCT -ge 90 ]]; then
  echo "Status: COMPLETE (would pass plan-review)"
elif [[ $PCT -ge 70 ]]; then
  echo "Status: BACKFILL NEEDED (write the missing sections, then re-score)"
else
  echo "Status: INCOMPLETE (drafter output is thin — re-draft before backfilling)"
fi

echo ""
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "--- Sections to backfill ---"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
fi
