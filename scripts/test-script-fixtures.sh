#!/usr/bin/env bash
#
# test-script-fixtures.sh - Automated runs of the per-skill SELF-TEST.md
# script fixtures
#
# Every skill that ships a score-*.sh/scan-*.sh script pins that script's
# happy path in its SELF-TEST.md: an inline heredoc fixture with exact
# expected counts, MISSING lists, exit codes, and per-style inventories.
# Those sections need no LLM in the loop — this script replays them
# mechanically and fails on any drift, so the pins stop being a manual
# runbook and become a regression net (the before/after guard for the
# lib/common.sh extraction).
#
# What is covered, per skill (each fixture is byte-faithful to the
# SELF-TEST.md section it mirrors — update the two together, deliberately):
#
#   plan-review        find-forks.sh    pinned summary counts + zero-hit + usage
#   spec-review        score-spec.sh    fixtures 6/13, 13/13, 0/13 + usage
#   plan-author        score-draft.sh   30/36 + exact backfill list + thin + usage
#   readme-review      score-readme.sh  12/14 + type ladder + placeholder + usage
#   api-design-review  scan-api.sh      4-style inventory + edge cases + usage
#   test-plan-review   scan-tests.sh    inventory counts + prune + frameworks + usage
#   release-readiness  scan-release.sh  fixture-repo facts + dirty tree + usage
#   diff-review        collect-diff.sh  local-repo modes (no network) + not-a-repo
#   repo-hygiene       repo_hygiene.sh  seeded violations + clean repo + JSON + usage
#
# Not automated, by design: the trigger-phrase and functional (LLM-in-the-loop)
# sections of each SELF-TEST.md stay manual runbooks, and plan-review's corpus
# smoke tests stay conditional on a research corpus CI does not have. The
# repo-hygiene fixture deliberately does NOT seed a dead .github/workflows/
# directory (dead-ci-workflows is the one detector left unexercised):
# creating .github/workflows/* is prohibited in this workspace, anywhere,
# even as a throwaway fixture.
#
# Everything runs against this repo checkout, never an installed copy — the
# score scripts source ../../lib/common.sh and installed copies lag. All
# fixtures live under one mktemp dir removed on exit; nothing outside it and
# the repo (read-only) is touched.
#
# Wired alongside scripts/validate-skills.sh and scripts/test-root-scripts.sh
# in the pre-commit hook (scripts/install-hooks.sh) and in the skills-validate
# Argo WorkflowTemplate (declarative-config k8s/iad-ci/argo-workflows/), so
# the pins gate commits locally and every push server-side.
#
# Usage:
#   scripts/test-script-fixtures.sh
#
# Exit codes: 0 = every pinned expectation holds, 1 = a pin broke

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0
FAILURES=()

# One temp root for every fixture; per-skill tests get subdirectories.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/jcs-fixtures.XXXXXX")"
if [[ "$WORK" != "${TMPDIR:-/tmp}"/* ]]; then
  echo -e "${RED}fixture root escaped tmp: $WORK${NC}" >&2
  exit 1
fi
trap 'rm -rf "$WORK"' EXIT

log_pass() { echo -e "${GREEN}  ✓ $1${NC}"; PASSED=$((PASSED + 1)); }
log_fail() {
  echo -e "${RED}  ✗ $1${NC}"
  FAILED=$((FAILED + 1))
  FAILURES+=("$1")
}

# Run a command, capturing combined output into REPLY and exit code into
# REPLY_RC. Everything below asserts against one captured run.
REPLY=""
REPLY_RC=0
run_capture() {
  REPLY_RC=0
  REPLY="$("$@" 2>&1)" || REPLY_RC=$?
}

assert_rc() { # expected_exit label
  local expected="$1" label="$2"
  if [[ "$REPLY_RC" == "$expected" ]]; then
    log_pass "$label (exit $REPLY_RC)"
  else
    log_fail "$label — expected exit $expected, got $REPLY_RC"
    echo "$REPLY" | tail -5 | sed 's/^/      /'
  fi
}

assert_has() { # label fixed-string [file-content...]
  local label="$1" needle="$2"
  if grep -qF -- "$needle" <<< "$REPLY"; then
    log_pass "$label"
  else
    log_fail "$label — output does not contain: $needle"
    echo "$REPLY" | tail -8 | sed 's/^/      /'
  fi
}

assert_not_has() { # label fixed-string
  local label="$1" needle="$2"
  if grep -qF -- "$needle" <<< "$REPLY"; then
    log_fail "$label — output must not contain: $needle"
    echo "$REPLY" | grep -F -- "$needle" | head -3 | sed 's/^/      /'
  else
    log_pass "$label"
  fi
}

assert_regex() { # label extended-regex
  local label="$1" pattern="$2"
  if grep -qE -- "$pattern" <<< "$REPLY"; then
    log_pass "$label"
  else
    log_fail "$label — output does not match: $pattern"
    echo "$REPLY" | tail -8 | sed 's/^/      /'
  fi
}

assert_eq() { # label got expected
  local label="$1" got="$2" expected="$3"
  if [[ "$got" == "$expected" ]]; then
    log_pass "$label"
  else
    log_fail "$label — mismatch"
    echo "      --- got ---" "$got" | sed 's/^/      /'
    echo "      --- expected ---" "$expected" | sed 's/^/      /'
  fi
}

# Exact multi-line block comparison (order + count + content): extracts the
# lines matching a prefix from $REPLY and diffs them against the expected
# block passed as a literal string.
assert_block() { # label grep-prefix expected-block
  local label="$1" prefix="$2" expected="$3"
  local got
  got="$(grep -F -- "$prefix" <<< "$REPLY" || true)"
  assert_eq "$label" "$got" "$expected"
}

skill_script() { # skill script... -> path inside this checkout
  echo "$REPO_ROOT/$1/scripts/$2"
}

# ---------------------------------------------------------------------------
# plan-review — find-forks.sh (SELF-TEST.md "find-forks.sh fixture test")
# ---------------------------------------------------------------------------

test_plan_review() {
  echo ""
  echo "=== plan-review: find-forks.sh fixture ==="
  local ff
  ff="$(skill_script plan-review find-forks.sh)"

  local fix="$WORK/plan-review-fixture.md"
  cat > "$fix" <<'EOF'
# Fixture Plan

## Architecture
- HTTP server (Rust, likely axum) — catch-all route.
- Cache store: SQLite on a PVC. Backup interval — candidate default: every 15 minutes.
- CI: Docker build → registry (target TBD, see Open Questions).
- Retry policy: exponential backoff with a sensible timeout.

## Decisions
**State store: SQLite, single writer.** Because: atomic writes. Rejected: Postgres. Revisit if: a second writer is required.
The system MUST NOT log the API key.

## Open Questions
- ~~API key source~~ — resolved 2026-07-15, OpenBao.
- Retention window: decided 2026-07-20 inline, 90 days.

## Phases
- Phase 1: core
- Phase 2: caching
- Phase 3: backup
- Phase 4: deploy
- Phase 5: docs
- Phase 6: hardening
- Phase 7: launch

## ADR-001: 2026-07-20 — Ratify something after the fact
Decision: yes.
EOF

  run_capture bash "$ff" "$fix"
  assert_rc 0 "fixture scan exits 0"
  assert_has "pinned summary counts" \
    "DEFER 1 · HEDGE 2 · SHADOW 2 · AMENDED 2 · UNQUANTIFIED 1 · DECIDED-markers 5"

  # Zero-hit case must not crash and must report all zeros.
  local tiny="$WORK/tiny.md"
  printf '# Tiny\n\nWe build a thing.\n' > "$tiny"
  run_capture bash "$ff" "$tiny"
  assert_rc 0 "zero-hit scan exits 0"
  assert_has "zero-hit summary is all zeros" \
    "DEFER 0 · HEDGE 0 · SHADOW 0 · AMENDED 0 · UNQUANTIFIED 0 · DECIDED-markers 0"

  run_capture bash "$ff"
  assert_rc 2 "usage error (no file) exits 2"
}

# ---------------------------------------------------------------------------
# spec-review — score-spec.sh (SELF-TEST.md "score-spec.sh fixture tests")
# ---------------------------------------------------------------------------

test_spec_review() {
  echo ""
  echo "=== spec-review: score-spec.sh fixtures ==="
  local sc
  sc="$(skill_script spec-review score-spec.sh)"
  local w="$WORK/spec-review"
  mkdir -p "$w"

  # --- Fixture A: mixed spec — passes exactly 6 of 13 ---
  cat > "$w/mixed.md" <<'EOF'
# Spec: Notification Digest Service

## Acceptance Criteria
- Acceptance scenario: a user with a verified email and 12 unread events requests a digest.
  Pass/fail is decided by the delivery receipt arriving within the stated budget.

## Success Metrics
- Success metric: p95 delivery latency under 500 ms at a sustained throughput of 200 events/s.
- Alert if the error budget burns 2x faster than target.

## Performance
- Sustained 200 events/s with p99 under 900 ms; load test before launch.

## Non-Goals
- Out of scope: SMS and push channels; a mobile client; per-user scheduling.
EOF

  run_capture bash "$sc" "$w/mixed.md"
  assert_rc 0 "fixture A exits 0"
  assert_has "fixture A score 6 / 13 (46%)"     "Structure score: 6 / 13 (46%)"
  assert_has "fixture A status NEEDS TIGHTENING" "Status: NEEDS TIGHTENING (run the full review)"
  assert_block "fixture A MISSING list exact (order + count)" "  MISSING: " '  MISSING: Security NFR
  MISSING: Scale / capacity
  MISSING: Data lifecycle
  MISSING: Roles / permissions
  MISSING: Assumptions
  MISSING: Dependencies
  MISSING: Open questions'
  assert_regex  "fixture A smell: fast x1 (substring in 'faster')" '^  fast +1$'
  assert_has    "fixture A total smells 1" \
    "Total ambiguity smells: 1 (each should be quoted and rewritten in the review)"

  # --- Fixture B: complete spec — 13/13, empty failures section ---
  cat > "$w/complete.md" <<'EOF'
# Spec: Notification Digest Service

## Acceptance Criteria
Each acceptance criterion is written pass/fail: given a verified email with 12 unread
events when the digest job runs, then exactly one receipt arrives within 500 ms.

## Success Metrics
- Success metric: p95 delivery latency under 500 ms at a sustained 200 events/s.

## Non-Goals
- Out of scope: SMS and push channels; a mobile client; per-user scheduling.

## Performance
- Sustained 200 events/s; p99 under 900 ms; measured against the load profile in Appendix A.

## Security
- Delivery addresses are personal data: encrypt at rest, and authentication is required
  for every endpoint. No credential is ever logged.

## Scale / Capacity
- Design capacity: 2,000 concurrent digest workers; 50M events/day volume at launch.

## Error Handling
- Invalid input is rejected with a 4xx; a broker timeout retries with backoff, then
  dead-letters after 5 attempts.

## Data Lifecycle
- Retention: receipts 90 days, then deletion. Export is available on request. Migration
  from the legacy table runs once at cutover.

## Roles
- Three roles: admin (full control), member (own subscriptions), auditor (read-only).

## Assumptions
- We assume the email broker sustains 250 events/s; revisit if the contract changes.

## Dependencies
- Depends on the identity service for verified addresses; third-party SMTP relay.

## Open Questions
- Open question: digest cadence — daily or hourly? Needs decision by 2026-10-01.

## Constraints
- Hard constraint: launch before the Q4 compliance audit; budget caps infra at $300/mo.
EOF

  run_capture bash "$sc" "$w/complete.md"
  assert_rc 0 "fixture B exits 0"
  assert_has     "fixture B score 13 / 13 (100%)" "Structure score: 13 / 13 (100%)"
  assert_has     "fixture B status READY FOR PLANNING" "Status: READY FOR PLANNING (minor gaps only)"
  assert_not_has "fixture B has no MISSING lines (empty-failures branch)" "MISSING:"
  assert_has     "fixture B total smells 0" "Total ambiguity smells: 0 (each should be quoted and rewritten in the review)"

  # --- Fixture C: thin spec — 0/13 ---
  printf '# Spec: Widget\n\nWe will build a widget.\n' > "$w/thin.md"
  run_capture bash "$sc" "$w/thin.md"
  assert_rc 0 "fixture C exits 0"
  assert_has "fixture C score 0 / 13 (0%)" "Structure score: 0 / 13 (0%)"
  assert_has "fixture C status NOT READY" \
    "Status: NOT READY (fundamental gaps — fix before a full review is worthwhile)"

  # --- Usage errors: 1, not a score failure ---
  run_capture bash "$sc"
  assert_rc 1 "usage error (no file) exits 1"
  assert_has  "usage error prints usage" "Usage: score-spec.sh <spec-file>"
  run_capture bash "$sc" "$w/nope.md"
  assert_rc 1 "usage error (missing file) exits 1"
}

# ---------------------------------------------------------------------------
# plan-author — score-draft.sh (SELF-TEST.md "score-draft.sh fixture tests")
# ---------------------------------------------------------------------------

test_plan_author() {
  echo ""
  echo "=== plan-author: score-draft.sh fixtures ==="
  local sc
  sc="$(skill_script plan-author score-draft.sh)"
  local w="$WORK/plan-author"
  mkdir -p "$w"

  cat > "$w/draft.md" <<'EOF'
# Plan: Digest Service 2.0

## 1. Scope Lock
North star: success is when a tenant receives one digest per day, on time, with zero dupes.
Non-goals: SMS and push channels are out of scope for this phase.
Hard requirements: the scheduler must not double-send during a lease transfer.

## 2. Acceptance
Acceptance scenario 1: given 12 unread events when the job runs, the receipt arrives.
pass: receipt within 500 ms. fail: duplicates or drops.
Recovery: if the broker is unreachable mid-sync, the lease expires and the run retries.

## 3. Architecture
Component overview: scheduler, renderer, relay.
Data flow traced end-to-end from event table to SMTP handoff.
Concurrency: single-writer lease; async workers.
Technology decision: Rust chosen over Python (why Rust over Python: lease semantics).

## 4. Data Model
Core entities: events, digests, receipts (schema below).
Source of truth: the events table; storage retention 90 days.

## 5. Pre-flight Safety
Edge cases: EC-1 clock skew, EC-2 partial render.
Failure modes: relay 5xx leads to backoff then dead-letter; recovery documented.
Rollback: feature flag off; state capture via the digest audit table.

## 6. Phases
Phase 0: walking skeleton (single tenant, manual trigger).
Phase 1: scheduler + lease. Phase 2: renderer.
Completion criteria: exit criteria per phase; a phase does not include unrelated refactors.

## 7. Testing
Unit tests for the renderer; integration test for the lease; testing strategy doc.
Quality gate: stop-ship on a flaky suite; definition of done includes docs.

## 8. Security
Threat model: spoofed From header; trivial because the relay enforces SPF.
Secrets: the SMTP credential comes from OpenBao and is never logged.

## 9. Performance
Performance budget: p99 render under 900 ms at 200 events/s.

## 10. Operations
Deployment: systemd unit, config non-interactive, CI mode supported.
Migration: the v1 table is kept read-only (keep / drop decision recorded).
Monitoring: health endpoint plus a doctor subcommand.

## 11. API
Interface: CLI command `digestsrv run`; exit code 0 on success.
Error contract: errors are surfaced as structured events with a stable code.

## 12. Risk
Risk register: R1 broker quota, likelihood medium, R2 schema drift.

## 13. Hygiene
Open questions: digest timezone default — resolve by 2026-10-01, owner: jedarden.
EOF

  run_capture bash "$sc" "$w/draft.md"
  assert_rc 0 "draft fixture exits 0"
  assert_has "draft score 30 / 36 (83%)" "Score: 30 / 36 (83%)"
  assert_has "draft status BACKFILL NEEDED" \
    "Status: BACKFILL NEEDED (write the missing sections, then re-score)"
  assert_block "backfill list exact (order + count)" "  MISSING: " '  MISSING: 1.4 Glossary
  MISSING: 1.5 Normative Language
  MISSING: 5.3 Invariants
  MISSING: 9.2 Measurement method
  MISSING: 12.2 Plan B
  MISSING: 13.2 Revision history'

  printf '# Plan\n\nWe will build a thing.\n' > "$w/thin.md"
  run_capture bash "$sc" "$w/thin.md"
  assert_rc 0 "thin draft exits 0"
  assert_has "thin draft score 0 / 36 (0%)" "Score: 0 / 36 (0%)"
  assert_has "thin draft status INCOMPLETE" \
    "Status: INCOMPLETE (drafter output is thin — re-draft before backfilling)"

  run_capture bash "$sc"
  assert_rc 1 "usage error (no file) exits 1"
  assert_has  "usage error prints usage" "Usage: score-draft.sh <plan-file>"
  run_capture bash "$sc" "$w/nope.md"
  assert_rc 1 "usage error (missing file) exits 1"
}

# ---------------------------------------------------------------------------
# readme-review — score-readme.sh (SELF-TEST.md "score-readme.sh fixture tests")
# ---------------------------------------------------------------------------

test_readme_review() {
  echo ""
  echo "=== readme-review: score-readme.sh fixtures ==="
  local sc
  sc="$(skill_script readme-review score-readme.sh)"
  local w="$WORK/readme-review/repo"
  mkdir -p "$w"
  touch "$w/Cargo.toml" "$w/LICENSE"   # library signal (no [[bin]]) + present LICENSE

  cat > "$w/README.md" <<'EOF'
# digestsrv

[![status](https://shields.io/badge/release-beta-blue)](https://example.invalid)

Delivery digest service that batches notification events into scheduled emails.

```bash
cargo install digestsrv
digestsrv --version
# You should see: digestsrv 0.4.1
```

## Prerequisites

You will need a Rust toolchain (1.75+) and a reachable SMTP relay.

## Installation

Install from source: `cargo install --path .`

## Quickstart

See the getting started example above, then send your first digest.

## Configuration

| Environment variable | Default | Meaning |
|---|---|---|
| `DIGESTSRV_SMTP_HOST` | — | relay hostname |

<!-- TODO: document the retry policy knobs -->

## API Reference

Endpoints exposed by the scheduler are documented in docs/api.md.

## Troubleshooting

Common issues: relay auth failures and clock skew.

## License

MIT. Copyright 2026 jedarden.
EOF

  run_capture bash "$sc" "$w/README.md"
  assert_rc 0 "README fixture exits 0"
  assert_has "detected type: library" "Detected project type: library (package manifest, no bin — confirm)"
  assert_has "repo signals: Cargo.toml" "Repo signals: Cargo.toml"
  assert_has "word count 117"      "Word count: 117"
  assert_has "9 headings (incl. the in-fence false positive)" "Top-level/section headings: 9"
  assert_has "score 12 / 14 (85%)" "Heuristic score: 12 / 14 (85%)"
  assert_has "status STRONG" "Status: STRONG (run the full review to catch depth/type gaps)"
  assert_block "MISSING list exact (4.2 + 4.6 only)" "  MISSING: " '  MISSING: 4.2 CONTRIBUTING
  MISSING: 4.6 Changelog'
  assert_has "placeholder scan line-numbered (4.7)" "31:<!-- TODO: document the retry policy knobs -->"

  # Type-detection ladder: docker > bin > library manifest > unknown.
  local t="$WORK/readme-review"
  mkdir -p "$t/t-cli" "$t/t-svc" "$t/t-unk"
  printf '{"name":"x","version":"0.1.0","bin":{"x":"cli.js"}}' > "$t/t-cli/package.json"
  printf '# x\n\nA tool.\n' > "$t/t-cli/README.md"
  touch "$t/t-svc/Dockerfile"
  printf '# x\n\nA service.\n' > "$t/t-svc/README.md"
  printf '# x\n\nSomething.\n' > "$t/t-unk/README.md"

  run_capture bash "$sc" "$t/t-cli/README.md"
  assert_has "ladder: bin entry -> CLI" "Detected project type: CLI (bin entry detected — confirm)"
  run_capture bash "$sc" "$t/t-svc/README.md"
  assert_has "ladder: Dockerfile -> service" "Detected project type: service (Dockerfile/compose present — confirm)"
  run_capture bash "$sc" "$t/t-unk/README.md"
  assert_has "ladder: no signals -> unknown" "Detected project type: unknown"

  run_capture bash "$sc"
  assert_rc 1 "usage error (no file) exits 1"
  run_capture bash "$sc" "$t/nope.md"
  assert_rc 1 "usage error (missing file) exits 1"
}

# ---------------------------------------------------------------------------
# api-design-review — scan-api.sh (SELF-TEST.md "scan-api.sh fixture test")
# ---------------------------------------------------------------------------

test_api_design_review() {
  echo ""
  echo "=== api-design-review: scan-api.sh fixture ==="
  local sc
  sc="$(skill_script api-design-review scan-api.sh)"
  local w="$WORK/api"
  mkdir -p "$w"

  cat > "$w/openapi.yaml" <<'EOF'
openapi: 3.0.0
paths:
  /users:
    get:
      summary: list
    post:
      summary: create
  /users/{id}:
    get:
      summary: fetch
EOF
  cat > "$w/schema.graphql" <<'EOF'
type Query {
  user(id: ID!): User
}
type Mutation {
  rename(id: ID!, name: String!): User
}
type User {
  id: ID!
  name: String!
}
EOF
  cat > "$w/svc.proto" <<'EOF'
syntax = "proto3";
message User { string id = 1; }
message RenameRequest { string id = 1; string name = 2; }
service Users {
  rpc GetUser(GetRequest) returns (User);
  rpc Rename(RenameRequest) returns (User);
  rpc List(ListRequest) returns (stream User);
}
EOF
  cat > "$w/routes.py" <<'EOF'
@router.get("/health")
@router.post("/digest")
app.patch("/config", set_config)
EOF
  printf '# not an API file\n' > "$w/README.md"   # decoy: must NOT be discovered

  run_capture bash "$sc" "$w"
  assert_rc 0 "directory scan exits 0"
  assert_has "REST inventory pinned"   "  [REST]    $w/openapi.yaml — paths:2 methods:3"
  assert_has "routes inventory pinned" "  [routes]  $w/routes.py — route-like registrations:3"
  assert_has "GraphQL inventory pinned" "  [GraphQL] $w/schema.graphql — types:3 queryBlock:1 mutationBlock:1"
  assert_has "gRPC inventory pinned"   "  [gRPC]    $w/svc.proto — services:1 rpcs:3 messages:2"
  assert_has "4 definition files"      "Detected 4 definition file(s). Feed the relevant one to the api-reviewer agent."
  assert_not_has "README decoy not discovered" "README.md"

  # Edge cases.
  run_capture bash "$sc"
  assert_rc 1 "usage error (no target) exits 1"
  run_capture bash "$sc" "$w/nope"
  assert_rc 1 "usage error (missing target) exits 1"
  mkdir -p "$w/empty"
  run_capture bash "$sc" "$w/empty"
  assert_rc 0 "empty dir is a report, not an error (exit 0)"
  assert_has "empty dir message" "No API definition files found under: $w/empty"
  run_capture bash "$sc" "$w/openapi.yaml"
  assert_rc 0 "single-file mode exits 0"
  assert_has "single-file mode: one REST line" "Detected 1 definition file(s)."
}

# ---------------------------------------------------------------------------
# test-plan-review — scan-tests.sh (SELF-TEST.md "scan-tests.sh fixture test")
# ---------------------------------------------------------------------------

test_test_plan_review() {
  echo ""
  echo "=== test-plan-review: scan-tests.sh fixture ==="
  local sc
  sc="$(skill_script test-plan-review scan-tests.sh)"
  local w="$WORK/proj"
  mkdir -p "$w/src" "$w/lib" "$w/tests" "$w/node_modules/pkg" "$w/vendor"

  cat > "$w/main.go" <<'EOF'
package main

func Sum(a, b int) int { return a + b }
EOF
  cat > "$w/main_test.go" <<'EOF'
package main

import "testing"

func TestSum(t *testing.T) {
	if Sum(1, 2) != 3 {
		t.Fail()
	}
}

func TestNegative(t *testing.T) {
	if Sum(-1, -1) != -2 {
		t.Fail()
	}
}
EOF
  cat > "$w/src/app.py" <<'EOF'
def run(digest):
    return digest.render()
EOF
  cat > "$w/src/helper.py" <<'EOF'
def pad(s):
    return " " + s
EOF
  cat > "$w/lib/parse.py" <<'EOF'
def parse(line):
    return line.split(",")
EOF
  cat > "$w/lib/parse_test.py" <<'EOF'
from parse import parse

def test_simple():
    assert parse("a,b") == ["a", "b"]

def test_spaces():
    assert parse(" a , b ") == [" a ", " b "]

def test_empty():
    assert parse("") == [""]
EOF
  cat > "$w/tests/test_api.py" <<'EOF'
def test_status():
    assert True

def test_list():
    assert True

def test_create():
    assert True

def test_delete():
    assert True
EOF
  printf 'module.exports = 1;\n' > "$w/node_modules/pkg/index.js"      # pruned
  printf 'package main\n\nfunc TestVendored(t *testing.T) {}\n' > "$w/vendor/v_test.go"  # pruned

  run_capture bash "$sc" "$w"
  assert_rc 0 "inventory scan exits 0"
  assert_has "totals pinned: 3 files, 9 functions" "Files: 3    Test functions: 9"
  assert_regex "lib/parse_test.py counted 3" '^[[:space:]]+3[[:space:]]+lib/parse_test\.py$'
  assert_regex "main_test.go counted 2"      '^[[:space:]]+2[[:space:]]+main_test\.go$'
  assert_regex "tests/test_api.py counted 4" '^[[:space:]]+4[[:space:]]+tests/test_api\.py$'
  assert_not_has "node_modules pruned from inventory"  "node_modules"
  assert_not_has "vendor pruned from inventory"        "v_test.go"
  assert_has "framework: go test"    "go test (Go)"
  assert_has "framework: pytest"     "pytest / unittest (Python)"
  assert_not_has "no jest in base fixture" "jest"
  assert_has "co-location: exactly 1 untested dir" "Source dirs lacking co-located tests: 1"
  assert_regex "flagged dir is src" '^  src$'

  # Sharp edge: framework detection does NOT honor the prune list — a test
  # named only under node_modules/ shows up in the framework list while the
  # file inventory stays at 3.
  printf "test('adds', () => { expect(1).toBe(1); });\n" > "$w/node_modules/pkg/index.js"
  run_capture bash "$sc" "$w"
  assert_has "sharp edge: jest detected from node_modules" "jest / mocha / vitest (JS/TS)"
  assert_has "sharp edge: file inventory still 3" "Files: 3    Test functions: 9"
  rm "$w/node_modules/pkg/index.js"

  run_capture bash "$sc"
  assert_rc 1 "usage error (no dir) exits 1"
  run_capture bash "$sc" "$WORK/nope"
  assert_rc 1 "usage error (missing dir) exits 1"
}

# ---------------------------------------------------------------------------
# release-readiness — scan-release.sh (SELF-TEST.md "scan-release.sh fixture test")
# ---------------------------------------------------------------------------

test_release_readiness() {
  echo ""
  echo "=== release-readiness: scan-release.sh fixture ==="
  local sc
  sc="$(skill_script release-readiness scan-release.sh)"
  local w="$WORK/rel"
  mkdir -p "$w"
  # The fixture uses the CI marker this workspace actually uses (.forgejo/) —
  # never seed a .github/workflows/ directory anywhere.
  (
    cd "$w"
    git -c init.defaultBranch=main init -q
    git config user.email "github@jedarden.com"
    git config user.name "jedarden"
    mkdir -p src .forgejo/workflows
    printf '# Changelog\n\n## 1.0.0\n- initial\n' > CHANGELOG.md
    printf 'def handle(evt):\n    return evt\n' > src/app.py
    git add CHANGELOG.md src/app.py && git commit -qm "v1.0.0 baseline"
    git tag v1.0.0
    printf 'def handle(evt):\n    # TODO: wire retries with backoff\n    return evt\n' > src/app.py
    git add src/app.py && git commit -qm "feat: mark retry work"
    printf 'def validate(evt):\n    # FIXME: reject unknown event types\n    raise ValueError\n' > src/handler.py
    git add src/handler.py && git commit -qm "feat: add handler skeleton"
    printf '{"name":"digestsrv","version":"1.1.0"}\n' > package.json
    printf '{"lockfileVersion":3}\n' > package-lock.json
    printf 'name: ci\non: [push]\njobs:\n  build:\n    runs-on: linux\n    steps:\n      - run: echo ok\n' > .forgejo/workflows/ci.yml
    git add package.json package-lock.json .forgejo/workflows/ci.yml && git commit -qm "chore: release metadata"
  )

  run_capture bash -c "cd '$w' && bash '$sc'"
  assert_rc 0 "scan exits 0"
  assert_has "last tag"        "Last release tag: v1.0.0"
  assert_has "range"           "Range: v1.0.0..HEAD"
  assert_has "3 commits"       "Commits since last release: 3"
  assert_has "subject: release metadata"  " chore: release metadata"
  assert_has "subject: handler skeleton"  " feat: add handler skeleton"
  assert_has "subject: retry work"        " feat: mark retry work"
  assert_has "5 changed files" "Changed files: 5"
  assert_has "changed: ci.yml"        "  .forgejo/workflows/ci.yml"
  assert_has "changed: package.json"  "  package.json"
  assert_has "changed: src/app.py"    "  src/app.py"
  assert_has "changed: src/handler.py" "  src/handler.py"
  assert_has "working tree clean" "Working tree: clean"
  assert_has "changelog found"    "  found: CHANGELOG.md"
  assert_has "version file found" "  found: package.json"
  assert_has "lockfile found"     "  found: package-lock.json"
  assert_has "CI config found"    "  found: .forgejo/workflows/ci.yml"
  assert_regex "marker hit pinned (app.py TODO)"     'src/app\.py:2:.*TODO: wire retries with backoff'
  assert_regex "marker hit pinned (handler FIXME)"   'src/handler\.py:2:.*FIXME: reject unknown event types'
  assert_has "marker count"    "(2 marker(s) found — review before release)"
  assert_has "scan completes"  "=== End Scan ==="

  # Dirty tree is itself a CONDITIONAL at best; restore afterwards.
  printf 'x\n' >> "$w/src/app.py"
  run_capture bash -c "cd '$w' && bash '$sc' | grep 'Working tree'"
  assert_has "dirty tree detected" "Working tree: DIRTY (uncommitted changes present)"
  git -C "$w" checkout -q -- src/app.py

  # Outside any git repo: usage + exit 1.
  run_capture bash -c "cd '$WORK' && bash '$sc'"
  assert_rc 1 "outside a repo exits 1"
  assert_has  "usage names the repo requirement" \
    "Usage: scan-release.sh [target-ref]   (must be run inside a git repository)"
}

# ---------------------------------------------------------------------------
# diff-review — collect-diff.sh (SELF-TEST.md "Script Smoke Tests", localized:
# the manual runbook clones from Forgejo; CI uses a local fixture repo so the
# check needs no network)
# ---------------------------------------------------------------------------

test_diff_review() {
  echo ""
  echo "=== diff-review: collect-diff.sh modes ==="
  local sc
  sc="$(skill_script diff-review collect-diff.sh)"
  local w="$WORK/diffrepo"
  mkdir -p "$w"
  (
    cd "$w"
    git -c init.defaultBranch=main init -q
    git config user.email "github@jedarden.com"
    git config user.name "jedarden"
    printf 'first line\n' > app.md
    git add app.md && git commit -qm "base"
    printf 'first line\nsecond line\n' > app.md
    git add app.md && git commit -qm "append second line"
  )

  run_capture bash -c "cd '$w' && bash '$sc' HEAD~1"
  assert_rc 0 "explicit base exits 0"
  assert_has "explicit-base mode named" "Mode : explicit base (HEAD~1)"
  assert_has "unified diff shows the added line" "+second line"

  printf 'third line\n' >> "$w/app.md"   # uncommitted
  run_capture bash -c "cd '$w' && bash '$sc'"
  assert_rc 0 "default invocation exits 0"
  assert_has "falls through to working-tree mode" "Mode : working-tree changes"
  assert_has "diff shows the uncommitted line" "+third line"

  run_capture bash -c "cd '$WORK' && bash '$sc'"
  assert_rc 1 "outside a repo exits 1"
  assert_has  "error names the work-tree requirement" "not inside a git work tree"
}

# ---------------------------------------------------------------------------
# repo-hygiene — repo_hygiene.sh (SELF-TEST.md "Script Smoke Tests", Test 3
# minus the dead-CI seeding: creating .github/workflows/* is prohibited in
# this workspace, so dead-ci-workflows stays the one unexercised detector)
# ---------------------------------------------------------------------------

test_repo_hygiene() {
  echo ""
  echo "=== repo-hygiene: repo_hygiene.sh fixtures ==="
  local sc
  sc="$(skill_script repo-hygiene repo_hygiene.sh)"
  local w="$WORK/hygiene"
  mkdir -p "$w/node_modules/lodash"
  (
    cd "$w"
    git -c init.defaultBranch=main init -q
    git config user.email "github@jedarden.com"
    git config user.name "jedarden"
    printf '{\n  "name": "test-repo",\n  "version": "1.0.0"\n}\n' > package.json
    printf 'fake module\n' > node_modules/lodash/index.js
    printf '# scratch\n' > test_scratch.sh
    dd if=/dev/zero of=large-blob.bin bs=1M count=6 2>/dev/null
    git add package.json node_modules/lodash/index.js test_scratch.sh large-blob.bin
    git commit -qm "seed violations"
  )

  run_capture bash "$sc" "$w"
  assert_rc 1 "findings repo exits 1"
  assert_has "category: tracked-build-artifacts (1)" "[high] tracked-build-artifacts — 1 finding(s)"
  assert_has "category: large-tracked-files (1)"     "[high] large-tracked-files — 1 finding(s)"
  assert_has "category: gitignore-gaps (1)"          "[medium] gitignore-gaps — 1 finding(s)"
  assert_has "category: root-ad-hoc-files (1)"       "[medium] root-ad-hoc-files — 1 finding(s)"
  assert_has "example: committed node_modules file"  "node_modules/lodash/index.js"
  assert_regex "example: large blob sized ~6 MB"     'large-blob\.bin \(6\.[0-9] MB\)'
  assert_has "exactly 4 finding categories" "4 finding categories. Report only — nothing was modified."

  run_capture bash "$sc" --json "$w"
  assert_rc 1 "JSON mode exits 1 on findings"
  assert_has "JSON: build artifacts"  '"category":"tracked-build-artifacts","severity":"high","count":1'
  assert_has "JSON: large file"       '"category":"large-tracked-files","severity":"high","count":1'
  assert_has "JSON: gitignore gap"    '"category":"gitignore-gaps","severity":"medium","count":1'
  assert_has "JSON: root ad hoc"      '"category":"root-ad-hoc-files","severity":"medium","count":1'
  assert_has "JSON: not clean"        '"clean":false'

  local clean="$WORK/hygiene-clean"
  mkdir -p "$clean"
  (
    cd "$clean"
    git -c init.defaultBranch=main init -q
    git config user.email "github@jedarden.com"
    git config user.name "jedarden"
    printf 'notes\n' > notes.txt
    git add notes.txt && git commit -qm "clean baseline"
  )
  run_capture bash "$sc" "$clean"
  assert_rc 0 "clean repo exits 0"
  assert_has "clean repo reports clean" "Clean — no findings."

  run_capture bash "$sc" "$WORK/nope"
  assert_rc 2 "usage error (missing path) exits 2"
  run_capture bash "$sc" "$WORK"
  assert_rc 2 "non-git directory exits 2"
}

# ---------------------------------------------------------------------------

main() {
  echo "SELF-TEST script-fixture runs for jeds-curated-skills"
  echo "Repo root: $REPO_ROOT"
  echo "(fixtures run against this checkout, not an installed copy)"

  test_plan_review
  test_spec_review
  test_plan_author
  test_readme_review
  test_api_design_review
  test_test_plan_review
  test_release_readiness
  test_diff_review
  test_repo_hygiene

  echo ""
  echo "========================================"
  echo "Script-Fixture Test Summary"
  echo "========================================"
  echo "Passed: $PASSED"
  echo "Failed: $FAILED"
  if [[ $FAILED -gt 0 ]]; then
    echo ""
    local f
    for f in "${FAILURES[@]}"; do
      echo -e "  ${RED}✗ $f${NC}"
    done
    echo ""
    echo -e "${RED}FAILED: $FAILED pinned expectation(s) broke${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASSED: all SELF-TEST script fixtures hold${NC}"
  exit 0
}

main "$@"
