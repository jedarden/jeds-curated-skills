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

**Expected (summary line):** `DEFER 1 · HEDGE 2 · SHADOW 2 · AMENDED 2 · UNQUANTIFIED 1 · DECIDED-markers 5`

- DEFER 1 → the CI line (`TBD` and "see Open Questions" on one line, counted once). The
  `## Open Questions` heading is excluded — headings are not deferrals.
- HEDGE 2 → `likely axum`; `candidate default`.
- SHADOW 2 → the `## ADR-001` header (it sits after the Open Questions heading); the `~~struck~~` line.
- AMENDED 2 → `resolved 2026-07-15`; `decided 2026-07-20`.
- UNQUANTIFIED 1 → `sensible timeout` (knob word, no digit on the line). The backup-interval
  line contains a digit, so it belongs to HEDGE, not here.
- DECIDED-markers 5 → the Form-1 SQLite line; `MUST NOT`; `decided 2026-07-20`; the ADR header; `Decision: yes`.

Also verify the zero-hit case does not crash: `printf '# Tiny\n\nWe build a thing.\n' > t.md && find-forks.sh t.md; echo exit=$?` → all zeros, `exit=0`.

If the counts differ, a pattern changed; update this table deliberately, never silently.

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
