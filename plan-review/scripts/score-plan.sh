#!/usr/bin/env bash
# Quick automated scoring of a plan against the core checklist.
# Usage: score-plan.sh <plan-file>
# Returns: score percentage and list of failing checks

set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: score-plan.sh <plan-file>" >&2
  exit 1
fi

PASS=0
FAIL=0
FAILURES=()

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

# Category 1: Scope Lock
check "1.1 North Star"               "north star" "one.sentence" "mission statement"
check "1.2 Non-Goals with Rationale" "non.?goal" "not.*goal" "out of scope"
check "1.3 Hard Requirements"        "hard requirement" "non.?negotiable" "must not" "forbidden"
check "1.4 Glossary"                 "glossary" "key term" "terminology" "defined as"
check "1.6 What It Is NOT"           "is not a" "not a " "what it.s not" "what this is not"

# Category 2: Acceptance Scenarios
check "2.1 Acceptance Scenarios"     "acceptance scenario" "scenario [0-9]" "user does"
check "2.2 Pass/Fail Criteria"       "pass criteria" "fail criteria" "passes when" "fails when"
check "2.4 Error/Degraded Scenario"  "offline" "degraded" "network.*down" "error scenario"

# Category 3: Architecture
check "3.1 Architecture Overview"    "architecture overview" "component model" "system overview"
check "3.2 Data Model"               "data model" "schema" "struct " "table.*columns"
check "3.4 Concurrency Model"        "concurrency" "thread" "async" "ownership model"
check "3.5 Tech Stack Rationale"     "why.*over" "chose.*because" "decision.*rationale" "trade.?off"
check "3.8 ADRs"                     "ADR" "decision record" "lock.*early" "churn.?magnet"
check "3.9 Open Questions"           "open question" "resolve before" "TBD.*phase" "unknown.*resolve"

# Category 4: Pre-Flight Safety
check "4.1 Edge Case Catalog"        "edge case" "EC-[0-9]" "edge cases:"
check "4.2 Failure Modes"            "failure mode" "failure taxonomy" "failure.*recovery"
check "4.3 Anti-Patterns"            "anti.?pattern" "what not to do" "pitfall" "avoid"
check "4.5 Rollback Plan"            "rollback" "roll back" "state.*capture" "undo.*command"
check "4.6 Offline/Degraded Mode"    "offline" "degraded mode" "without network"
check "4.7 Invariants"               "invariant" "must always" "always hold"

# Category 5: Phasing
check "5.1 Phases Named"             "phase [0-9]" "phase [a-e]:" "track [a-e]"
check "5.2 Completion Criteria"      "completion criteria" "done when" "exit criteria"
check "5.3 Walking Skeleton"         "walking skeleton" "phase 0" "minimal.*end.to.end"

# Category 6: Testing
check "6.1 Testing Strategy"         "testing strategy" "test plan" "unit test" "integration test"
check "6.5 Quality Gates"            "quality gate" "stop.ship" "definition of done" "must pass"
check "6.6 All-Gates Policy"         "same commit" "all.*pass" "lint.*test.*bench"

# Category 7: Security
check "7.1 Threat Model"             "threat model" "threat.*attacker" "attack surface"
check "7.2 Secrets Handling"         "secrets" "api key" "credential" "never log"

# Category 8: Performance
check "8.1 Performance Budget"       "p50" "p99" "latency.*<" "ms.*budget" "performance budget"
check "8.2 Benchmark Contract"       "benchmark.*contract" "measure.*methodology" "3x.*claim"

# Category 9: Operations
check "9.1 Deployment Plan"          "deployment" "installation" "how to install" "getting started"
check "9.3 Backward Compat Stance"   "backward compat" "backwards compat" "breaking change" "compatibility"
check "9.6 Non-Interactive Mode"     "non.?interactive" "ci mode" "\-\-yes" "\-\-no.?interactive"
check "9.8 Doctor Command"           "doctor" "health check" "self.?test.*command" "\`doctor\`"

# Category 11: Risk
check "11.1 Risk Register"           "risk register" "risk.*likelihood" "risk.*impact" "risk.*mitigation"
check "11.2 Plan B"                  "plan b" "fallback" "alternative.*approach" "if.*fails.*instead"

# Tally
TOTAL=$((PASS + FAIL))
PCT=$(( PASS * 100 / TOTAL ))

echo "=== Plan Score: $FILE ==="
echo ""
echo "Score: $PASS / $TOTAL ($PCT%)"
echo ""

if [[ $PCT -ge 80 ]]; then
  echo "Status: READY (minor gaps only)"
elif [[ $PCT -ge 60 ]]; then
  echo "Status: NEEDS WORK (address critical gaps before implementing)"
else
  echo "Status: NOT READY (significant gaps — implementation will pivot)"
fi

echo ""
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "--- Missing Checks ---"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
fi
