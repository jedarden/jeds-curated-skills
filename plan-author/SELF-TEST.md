# Self-Test: plan-author

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "write a plan for…" · "turn this brief into a plan" · "draft a plan.md" | Activates |
| "start a new project" · "I have an idea, plan it" | Activates |
| "/plan-author <brief-or-path>" · "/plan-author --out docs/plan/plan.md" | Activates |
| "review this plan" | Does NOT activate — that is `plan-review` (the inverse skill) |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"   # repo checkout; installed copies lag (see note)
SKILL_DIR="$REPO/plan-author"
ls -1 "$SKILL_DIR"                # CHECKLIST-COMPLETENESS.md, PLAN-TEMPLATE.md, SELF-TEST.md,
                                  # SKILL.md, references/, runbooks/, scripts/, subagents/
ls -1 "$SKILL_DIR/references"     # EXAMPLES.md SECTION-TAXONOMY.md
ls -1 "$SKILL_DIR/runbooks"       # FROM-EXISTING-CODE.md
ls -1 "$SKILL_DIR/scripts"        # score-draft.sh
test -x "$SKILL_DIR/scripts/score-draft.sh" && echo "ok: executable"
```

Run the script tests against a **repo checkout**: the script sources
`../../lib/common.sh`, and an installed copy without `lib/` fails to source at all.

## `score-draft.sh` fixture tests

The script runs 36 completeness checks (the eleven plan-review categories, mirrored from
CHECKLIST-COMPLETENESS.md). The fixture below is built to pass **exactly 30 of 36** — it
deliberately omits six sections so both the pass and fail paths of the shared `check()` and
the backfill list are exercised. Any drift in the score or the MISSING list means a pattern
changed. Update this file deliberately, never silently.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/draft.md" <<'EOF'
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
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/draft.md"
echo "exit=$?"
```

**Expected:**

```
Score: 30 / 36 (83%)
Status: BACKFILL NEEDED (write the missing sections, then re-score)
```

`--- Sections to backfill ---` lists **exactly these six**, in this order:

```
  MISSING: 1.4 Glossary
  MISSING: 1.5 Normative Language
  MISSING: 5.3 Invariants
  MISSING: 9.2 Measurement method
  MISSING: 12.2 Plan B
  MISSING: 13.2 Revision history
```

Why each of the six is missing: the fixture has no glossary/terminology block, no
RFC-2119 normative-language note, no invariants ("must always hold"), no *how performance
is measured* line (it states a budget but never the word "measured"/"benchmark"), no
Plan B/fallback, no revision-history line. Everything else passes on the visible words —
e.g. 12.1 on `R1 ` + `likelihood`, 10.2 on `keep / drop`, 6.1 on `walking skeleton` +
`phase 0`. Several patterns are broad (`fail` alone satisfies 11.2; `storage` satisfies
4.2) — that breadth is the heuristic's design, not a bug to fix silently.

```bash
# --- Thin draft: 0/36, bottom status branch ---
printf '# Plan\n\nWe will build a thing.\n' > "$WORK/thin.md"
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/thin.md" | grep -E 'Score|Status'
# → Score: 0 / 36 (0%)
# → Status: INCOMPLETE (drafter output is thin — re-draft before backfilling)

# --- Usage errors ---
"$REPO/plan-author/scripts/score-draft.sh"; echo "exit=$?"                  # exit=1
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/nope.md"; echo "exit=$?"  # exit=1
```

Both usage errors print `Usage: score-draft.sh <plan-file>` to stderr. Successful runs
always exit 0 — a low completeness score is coaching output, not a failure.

## Functional Test (LLM in the loop)

Run `/plan-author` on a one-paragraph brief (e.g. "a CLI that watches a mailbox and files
beads for every bounce"). Expected:

- At most **three** scoping AskUserQuestions before drafting (per SKILL.md Step 1).
- The draft contains all eleven categories and opens questions as numbered Open Questions
  with owners and resolve-by dates — never a bare "TBD".
- `score-draft.sh` on the generated plan scores ≥ 90% (`Status: COMPLETE`); if lower, the
  drafter backfills the listed sections rather than shipping thin.
- A second `/plan-review` pass on the draft finds no UNNOTICED forks (the two skills are
  inverse: author targets what review checks).

## Expected Behaviors

- **Score mirrors the checklist**: every `check` line in the script corresponds to a
  CHECKLIST-COMPLETENESS.md item; keep the two in sync when editing either.
- **Exit codes**: 0 on any successful scoring, 1 on usage error.
- **Status bands**: ≥ 90 COMPLETE · 70–89 BACKFILL NEEDED · < 70 INCOMPLETE.
- **Substrate-agnostic**: matching is grep over visible words — writing the words without
  doing the thinking defeats your own gate; the full `/plan-review` is the real judge.
