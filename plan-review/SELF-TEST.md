# Self-Test: plan-review 2.0

## Trigger phrases

| Phrase | Expected |
|---|---|
| "review my plan" · "pre-flight check on this plan" · "is this plan ready to implement?" | Activates |
| "what's missing from this plan?" · "check my spec for gaps" | Activates |
| "what decisions does this plan leave open?" · "why do we keep writing ADRs for this project?" | Activates |
| "/plan-review path/to/plan.md" · "/plan-review --fast" · "/plan-review --lock all" | Activates (full / fast / lock) |
| "turn this plan into beads" | Does NOT activate — that is `plan-to-bead` (it may *suggest* a review first) |

## Structure

```bash
SKILL_DIR="$HOME/.claude/skills/plan-review"
ls -1 "$SKILL_DIR"                       # SKILL.md REPORT-TEMPLATE.md SELF-TEST.md references/ runbooks/ scripts/
ls -1 "$SKILL_DIR/references"            # DECISION-LEDGER.md EXEMPLARS.md SECTION-HEADER-TAXONOMY.md STRUCTURAL-SWEEP.md
ls -1 "$SKILL_DIR/runbooks"              # FAST-PATH.md LOCK.md MULTI-PLAN-COMPARISON.md
ls -1 "$SKILL_DIR/scripts"               # find-forks.sh scan-headers.sh (score-plan.sh deprecated, unreferenced)
test ! -d "$SKILL_DIR/subagents" && echo "ok: no subagents (inline by design)"
grep -q '^version: 2' "$SKILL_DIR/SKILL.md" && echo "ok: version 2.x"
```

## `find-forks.sh` fixture test

The fixture has known counts. Any drift in the patterns shows up here.

```bash
SKILL_DIR="$HOME/.claude/skills/plan-review"
FIX="$(mktemp)"
cat > "$FIX" <<'EOF'
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
"$SKILL_DIR/scripts/find-forks.sh" "$FIX"
rm -f "$FIX"
```

**Expected (summary line):** `DEFER 1 · HEDGE 2 · SHADOW 2 · AMENDED 2 · UNQUANTIFIED 1 · PROD-ORACLE 0 · DECIDED-markers 5`

- DEFER 1 → the CI line (`TBD` and "see Open Questions" on one line, counted once). The
  `## Open Questions` heading is excluded — headings are not deferrals.
- HEDGE 2 → `likely axum`; `candidate default`.
- SHADOW 2 → the `## ADR-001` header (it sits after the Open Questions heading); the `~~struck~~` line.
- AMENDED 2 → `resolved 2026-07-15`; `decided 2026-07-20`.
- UNQUANTIFIED 1 → `sensible timeout` (knob word, no digit on the line). The backup-interval
  line contains a digit, so it belongs to HEDGE, not here.
- DECIDED-markers 5 → the Form-1 SQLite line; `MUST NOT`; `decided 2026-07-20`; the ADR header; `Decision: yes`.
- PROD-ORACLE 0 → nothing in this fixture admits that production is the only test; see the
  negative fixture below for the positive case.

Also verify the zero-hit case does not crash: `printf '# Tiny\n\nWe build a thing.\n' > t.md && find-forks.sh t.md; echo exit=$?` → all zeros (`… · PROD-ORACLE 0 · DECIDED-markers 0`), `exit=0`.

If the counts differ, a pattern changed; update this table deliberately, never silently.

## Negative fixture — the compound rewrite whose only oracle was production

Cut from the tradegraph-platform plan that was decomposed into 298 beads without a review
and rolled back ten weeks later (2026-10-20). It is deliberately well-formed: typed, dated,
phased, gated. Every structural check it would pass is the point — only the caps catch it.

```bash
SKILL_DIR="$HOME/.claude/skills/plan-review"
NEG="$(mktemp)"
cat > "$NEG" <<'EOF'
# Trading Platform — consolidated architecture and implementation plan

**Type:** Port
**Status:** v1.20 · **Last updated:** 2026-09-06

## 1. Outcome and scope

### 1.2 Three separately gated workstreams

| Workstream | Outcome |
|---|---|
| A — Consolidation and shared infrastructure | Port the research MCP, the journal and the broker service into one platform |
| B — Expanded intelligence | Event-first discovery, lineage, bridges, ranking |
| C — Operating readiness | A rehearsed daily workflow and a separately commissioned execution path |

All three ship on one platform version from one repository; every component releases together.

## 13. Operating workflows

### 13.5 Tuesday, September 8 target runbook

This is a requested operating target, not a claim of readiness.

## 14. Migration phases

| Phase | Work | Completion evidence |
|---|---|---|
| 0 — Consolidated baseline | This plan, source provenance, requirements, conflict dispositions | Validated documents published |
| 1 — Inventory, contracts, safety seam | Source baselines; typed read/command/event schemas; identities; old-engine fixtures | Import manifest; denial tests |
| 2 — Shared broker reads and capture | After 1: extract client/session/cache under one owner | Same-identity read parity |
| 3 — Execution transport extraction | After 1–2: the execution engine uses shared broker commands | Two-hop response-loss, idempotency, recovery tests |
| 4 — Unified journal and facade | After 1 | Real-database invariants |
| 5 — Bounded discovery | After 2/4 | T1/T2 rehearsal |
| 6 — Advanced intelligence | After 5 | Forward cohorts |
| 7 — Retirement | After each capability's parity gates | Retirement record |

## 15. Verification and release gates

Sixteen gates, G01–G16, each requiring evidence against the release candidate. Live broker
mutations require separately scoped commissioning; see §19.6 for why this commissioning runs
on the single production account rather than a paper account.

## 19. Decision dispositions

### 19.6 Paper commissioning not available; live tests reproduce the legacy broker's capabilities instead

The broker offers no paper account for this entitlement set. Execution behaviour is proven by
ported legacy unit tests against fixtures, and then by live drills on the production account
during the cutover window.
EOF
"$SKILL_DIR/scripts/find-forks.sh" "$NEG"
rm -f "$NEG"
```

**Expected (summary line):** `DEFER 0 · HEDGE 1 · SHADOW 0 · AMENDED 0 · UNQUANTIFIED 1 · PROD-ORACLE 3 · DECIDED-markers 0`

- PROD-ORACLE 3 → `:41` "single production account rather than a paper account"; `:45` the
  §19.6 heading ("Paper commissioning not available; live tests reproduce"); `:47` "no paper
  account". Headings are *not* excluded for this category — the admission usually is one.
- HEDGE 1 → "release candidate" (`candidate`); UNQUANTIFIED 1 → "cutover window" with no
  number. Both are noise here and show why the locator is not a verdict.
- The trailing hint names Cap C9.

**LLM in the loop:** `/plan-review` on this fixture must return **NOT READY** with three caps
tripped and name them in the memo's caps table:

| Cap | Expected | Evidence the memo must cite |
|---|---|---|
| C3 | **TRIPPED** | Phase 0 is documents, Phase 1 is contracts; the broker is first touched in Phase 3 |
| C8 | **TRIPPED** | §1.2: three workstreams, "one platform version from one repository" |
| C9 | **TRIPPED** | §19.6 and §15: production account is the only oracle; ported tests do not count |
| C10 | n/a | 49 lines |

Lens C must also flag the §13.5 date: September 8 precedes any phase that could touch the
broker. A review that returns READY AFTER DECISIONS on this fixture has lost the caps.

## `scan-headers.sh` fixture test

Same fixture document as `find-forks.sh` above — one byte-identical input pins
both plan-review scripts.

```bash
SKILL_DIR="$HOME/.claude/skills/plan-review"
# reuse $FIX from the find-forks fixture above
"$SKILL_DIR/scripts/scan-headers.sh" "$FIX"
```

**Expected:**

- `--- All Headers ---` lists exactly six, with line numbers: `1:# Fixture Plan`,
  `3:## Architecture`, `9:## Decisions`, `13:## Open Questions`, `17:## Phases`,
  `26:## ADR-001: 2026-07-20 — Ratify something after the fact` (the
  post-Open-Questions header find-forks flags as SHADOW).
- `--- Header Counts ---`: `H1 (# ): 1`, `H2 (## ): 5`, `H3 (### ): 0` — followed by
  a bare `0` line. **Known quirk:** the header-count helper computes
  `$(grep -c … || echo 0)`, and `grep -c` already prints `0` before exiting 1, so
  every zero level emits a second, bare `0`. Pinned as a quirk, not silently
  "fixed" (same precedent as usage-statusline's empty-cache pin); fixing the
  helper is fine — update this section and the
  `scripts/test-script-fixtures.sh` fixture in the same commit.
- `--- Key Section Presence ---`: exactly 2 PRESENT — `Architecture Overview` and
  `ADRs / Design Decisions` — and 17 MISSING. The document deliberately has no
  Non-Goals or Glossary section, so those verdicts are MISSING.
- `--- File Stats ---`: `Total lines : 27`, `Total words : 136`,
  `Total chars : 821` (bytes — the em-dashes and the arrow are multibyte).
- No-header document: `printf 'plain prose only\nno headers at all\n' > t.md`
  then `scan-headers.sh t.md` → `--- All Headers ---` prints `(no headers found)`,
  exit 0 — the `|| echo` fallback reports, it does not crash.
- No argument / missing file: `Usage: scan-headers.sh <plan-file>`, exit 1.

If any pin differs, `scan-headers.sh` (or the shared header-count helper it
calls) changed; update this section and the fixture suite together, deliberately.

## Corpus smoke tests (if the research corpus is present)

```bash
CORPUS="$HOME/Research/dicklesworthstone-plan-corpus/documents"
SKILL_DIR="$HOME/.claude/skills/plan-review"
# A spike plan: expect `DEFER 2` (two "(TBD)" owners) and zeros elsewhere; the review should
# classify it as Spike and judge it by S.1–S.6 (question, metrics, environment, time box,
# where recorded, default) — not by the structural categories.
"$SKILL_DIR/scripts/find-forks.sh" "$CORPUS/rust_scriptbots/docs/wasm/rendering_spike_plan.md" --quiet
# A heavily-locked plan: its front-loaded "§0.13 ADR Expansions (Lock Churn-Magnets Early)" at
# ~10% of the file must NOT be flagged as SHADOW — that is exactly where decisions belong. Any
# ADR headers past the Open Questions heading and past 40% of the file are flagged; inspect them.
"$SKILL_DIR/scripts/find-forks.sh" "$CORPUS/frankentui/docs/planning/plan-to-create-frankentui-opus.md" --quiet
```

## Functional test (LLM in the loop)

Run `/plan-review` on a plan that has an ADR appended after its Open Questions. Expected:

- Verdict is **not** expressed as a percentage.
- The appended ADR surfaces as a **SHADOW** ledger entry with a proposal to fold it into its home section.
- Every DN carries **Decision / Because / Rejected / Enforced by / Revisit if**.
- The dry run names at least one concrete first question with a line anchor.
- The memo is written to `docs/notes/plan-review-<date>.md` (or next to the plan) before the chat summary.
- The plan file itself is **unmodified** after the review pass (`git diff --stat` shows nothing for it).
- `--lock DN-1` then modifies the plan at the fork's home section, not at the end, and leaves it uncommitted.
