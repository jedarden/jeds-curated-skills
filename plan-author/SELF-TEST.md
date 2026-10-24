# Self-Test: plan-author

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "write a plan for…" · "turn this brief into a plan" · "draft a plan.md" | Activates |
| "start a new project" · "I have an idea, plan it" | Activates |
| "plan this database cutover" · "write a migration plan" | Activates — classifies as Migration / Cutover |
| "run a spike to choose between these approaches" | Activates — classifies as Spike |
| "/plan-author <brief-or-path>" · "/plan-author --out docs/plan/plan.md" | Activates |
| "review this plan" | Does NOT activate — that is `plan-review` (the inverse skill) |

## Structure

Run these snippets from the repository root, or set `REPO` to the checkout path.

```bash
REPO="${REPO:-$PWD}"   # repo checkout; installed copies lag (see note)
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

The script runs 39 base completeness checks (the eleven plan-review categories, mirrored from
CHECKLIST-COMPLETENESS.md, including the three cap-backed checks 6.4, 7.3 and 7.4 added after
the tradegraph-platform rollback), plus five Port, six Migration / Cutover or six Spike checks
when the type metadata selects them. The fixture below is built to pass **exactly 30 of 39** —
it deliberately omits nine sections so both the pass and fail paths of the shared `check()` and
the backfill list are exercised. Any drift in the score or the MISSING list means a pattern
changed. Update this file deliberately, never silently.

```bash
REPO="${REPO:-$PWD}"
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
Score: 30 / 39 (76%)
Status: BACKFILL NEEDED (write the missing sections, then re-score)
```

`--- Sections to backfill ---` lists **exactly these nine**, in this order:

```
  MISSING: 1.4 Glossary
  MISSING: 1.5 Normative Language
  MISSING: 5.3 Invariants
  MISSING: 6.4 First slice hits the riskiest dependency
  MISSING: 7.3 Oracle access
  MISSING: 7.4 Inner-loop budget
  MISSING: 9.2 Measurement method
  MISSING: 12.2 Plan B
  MISSING: 13.2 Revision history
```

Why each of the nine is missing: the fixture has no glossary/terminology block, no
RFC-2119 normative-language note, no invariants ("must always hold"), no statement that
Phase 0 exercises the riskiest real dependency (no "real dependency exercised",
"riskiest", "without a production event"), no test oracle (no "oracle", "replay",
"sandbox account", "shadow comparison"), no inner-loop budget, no *how performance
is measured* line (it states a budget but never the word "measured"/"benchmark"), no
Plan B/fallback, no revision-history line. Everything else passes on the visible words —
e.g. 12.1 on `R1 ` + `likelihood`, 10.2 on `keep / drop`, 6.1 on `walking skeleton` +
`phase 0`. Several patterns are broad (`fail` alone satisfies 11.2; `storage` satisfies
4.2; a lone "oracle" satisfies 7.3) — that breadth is the heuristic's design, not a bug to
fix silently; the full `/plan-review` and its Cap C9 are the real judge of 7.3.

```bash
# --- Thin draft: 0/39, bottom status branch ---
printf '# Plan\n\nWe will build a thing.\n' > "$WORK/thin.md"
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/thin.md" | grep -E 'Score|Status'
# → Score: 0 / 39 (0%)
# → Status: INCOMPLETE (drafter output is thin — re-draft before backfilling)

# --- Usage errors ---
"$REPO/plan-author/scripts/score-draft.sh"; echo "exit=$?"                  # exit=1
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/nope.md"; echo "exit=$?"  # exit=1
```

Both usage errors print `Usage: score-draft.sh <plan-file>` to stderr. Successful runs
always exit 0 — a low completeness score is coaching output, not a failure.

## Type-specific authoring checks

The scorer must add the applicable controls and leave the other type's controls out. Append each
fixture below to the base `draft.md` from the preceding test; the base fixture intentionally still
misses its six generic sections, so these checks pin the conditional totals and the absence of
type-specific failures:

```bash
cat "$WORK/draft.md" > "$WORK/migration.md"
cat >> "$WORK/migration.md" <<'EOF'

**Type:** Migration / Cutover
## Type-Specific Requirements
Backup and restore rehearsal; idempotent and resumable steps; shadow/canary with a diff oracle;
cutover gate and rollback trigger; post-cutover validation and old-path retirement.
EOF
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/migration.md"
# → Score: 37 / 45 (82%); no MISSING: M. lines
#   (37, not 36: the M.3 line's "diff oracle" also satisfies base check 7.3 — the breadth
#    noted above; M.6 passes on "rehearsal … shadow" on one line)

cat "$WORK/draft.md" > "$WORK/spike.md"
cat >> "$WORK/spike.md" <<'EOF'

**Type:** Spike
## Type-Specific Requirements
Question answerable by a measurement; metrics and thresholds; environment; time box and decide-by
gate; decision record in the informed plan; default if inconclusive.
EOF
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/spike.md"
# → Score: 36 / 45 (80%); no MISSING: S. lines

cat "$WORK/draft.md" > "$WORK/port.md"
cat >> "$WORK/port.md" <<'EOF'

**Type:** Port
## Type-Specific Requirements
Source metrics: LOC by subsystem measured; capability slices each retire one legacy path with a size cap;
conformance harness against the original; porting order by dependency layer; not-ported list recorded.
EOF
"$REPO/plan-author/scripts/score-draft.sh" "$WORK/port.md"
# → Score: 36 / 44 (81%); no MISSING: P. lines
#   (36: the Port line's "measured" also satisfies base check 9.2)
```

The template and checklist must expose the same P.1–P.5, M.1–M.6 and S.1–S.6 controls. A
complete Port plan therefore has 44 checks, a complete Migration / Cutover 45 and a complete
Spike 45; a generic 39/39 score is not sufficient for any of them.

## Functional Test (LLM in the loop)

Run `/plan-author` on a one-paragraph brief (e.g. "a CLI that watches a mailbox and files
beads for every bounce"). Expected:

- At most **three** scoping questions before drafting (per SKILL.md Step 1).
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
- **Conditional type controls**: Port adds P.1–P.5; Migration / Cutover adds M.1–M.6; Spike
  adds S.1–S.6; the non-applicable blocks do not affect the score.
- **Cap-backed base checks**: 6.4, 7.3 and 7.4 mirror plan-review caps C3 and C9 and ledger
  fork 6.14. A draft that scores COMPLETE while its Phase 0 is documents or its only oracle
  is production has written the words without the thinking; the review still trips.
- **Compound briefs are split**: a brief that is port + migration + integration + new
  features yields one plan for the first-shipping type with the rest as held non-goals in §2,
  never one plan with every workstream in the phase table.
- **Substrate-agnostic**: matching is grep over visible words — writing the words without
  doing the thinking defeats your own gate; the full `/plan-review` is the real judge.
