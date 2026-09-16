# Self-Test: migration-runbook

Prose-only skill — the surface is `CHECKLIST-SAFETY.md` (12 items, 5 of them
non-negotiable per SKILL.md Step 5) plus mechanical author-flow behavior
(pattern selection, sequence numbering is adr's, here: report shape). The
regression shape is a fixture runbook built to fail nearly everything, so each
checklist item has a known rating.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "write a runbook for the schema migration" | Activates |
| "we're moving to a new database — plan the cutover" | Activates |
| "make this backfill safe to abort" | Activates |
| "/migration-runbook docs/migration-brief.md" | Activates |
| "write an ADR about the migration decision" | Does NOT activate — adr skill records the decision; this skill writes the runbook |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SKILL_DIR="$REPO/migration-runbook"
ls -1 "$SKILL_DIR"              # CHECKLIST-SAFETY.md, RUNBOOK-TEMPLATE.md,
                                # SELF-TEST.md, SKILL.md, references/,
                                # runbooks/, subagents/
ls -1 "$SKILL_DIR/references"   # MIGRATION-PATTERNS.md, ROLLBACK-PATTERNS.md
ls -1 "$SKILL_DIR/runbooks"     # ZERO-DOWNTIME.md
ls -1 "$SKILL_DIR/subagents"    # runbook-author.md
```

## Review-mode fixture

A deliberately unsafe runbook. Planted defects are annotated inline — a real
review sees them without the comments:

```bash
T="$(mktemp -d)"
cat > "$T/MIGRATION-RUNBOOK.md" <<'EOF'
# Runbook: users table consolidation

## Steps

1. Announce the change in the team channel.
   - Verify: post the announcement.
2. Deploy the new application version (reads and writes both tables).
   - Verify: check the deploy finished. (planted: "check" — no observable signal)
3. Copy users_old into users_new in one statement:
   `INSERT INTO users_new SELECT * FROM users_old;`
   (planted: no batch, no dry run, no snapshot, not idempotent — re-run
   duplicates rows; and this step has neither rollback nor PNR marker)
   - Verify: it probably worked if the command returns. (planted: not a gate)
4. `DROP TABLE users_old;` (planted: destructive, no backup step, unmarked PNR)
5. Update the DNS record to point at the new service. (planted: irreversible,
   TTL-dependent, unmarked, no last-safe-abort point)
   - Verify: the site loads.
6. Done. (planted: no phase gates, no monitoring, no RPO/RTO anywhere)

## Rollback

Re-run the steps in reverse if something looks wrong. (planted: untested,
hand-waved, impossible after step 4)
EOF
echo "$T" > /tmp/mr-selftest-dir
```

**Expected inventory — `/migration-runbook <fixture>` self-check or review
rates it:**

| Item | Rating | Because (the planted defect) |
|------|--------|------------------------------|
| 1.1 Per-step reversibility | MISSING | Steps 3–5 have neither rollback nor PNR marker — a defect, no third option |
| 1.2 Per-step verification gate | PARTIAL | Steps 1, 5 have observable-ish signals; 2–4 are "probably worked" |
| 1.3 Idempotency / safe re-run | MISSING | Step 3 re-run duplicates rows |
| 1.4 Dry-run available | MISSING | None; step 3 is raw against prod data |
| 1.5 Explicit abort criteria | MISSING | Nothing pre-committed |
| 1.6 Backup before destructive steps | MISSING | `DROP TABLE` with no snapshot |
| 1.7 Monitoring during cutover | MISSING | No signals, dashboards, or thresholds |
| 1.8 Points-of-no-return marked | MISSING | Steps 4–5 are irreversible and unmarked |
| 1.9 No big-bang | MISSING | Single all-at-once statement copy |
| 1.10 Rollback tested first | MISSING | "re-run in reverse", never exercised |
| 1.11 Validation gates between phases | MISSING | No phases, no gates |
| 1.12 RPO/RTO bounded | MISSING | Never mentioned |

Hard pins: **0 PRESENT / 1 PARTIAL / 11 MISSING**, and every one of the five
non-negotiables (SKILL.md Step 5) is among the MISSING — the skill must
**refuse to deliver** this runbook and loop back to repair, not print it with
a scorecard. The five non-negotiables failing is the load-bearing regression
pin: a checklist or Step-5 edit that lets any of 1.1/1.6/1.8/1.9/1.10 slide
here has broken the skill's core promise.

## Author-mode checks

Mechanical pattern selection (Step 2) — the briefs below each pin one pattern
from references/MIGRATION-PATTERNS.md:

| Brief | Expected pattern(s) |
|-------|---------------------|
| Add a NOT NULL column to a large table, zero downtime | Expand-contract (parallel change) |
| Move sessions from Postgres to Redis while serving live traffic | Dual-write + backfill |
| Swap the whole staging environment to new infra, instant shift-back | Blue-green |
| Verify a new search path before trusting it | Shadow / read-compare |

LLM in the loop, `/migration-runbook "<brief>"` on a real brief:

- Asks at most 2–3 scoping questions, and only when ≥ 2 of the four facts
  (From→To, downtime tolerance, volume, reversibility) are thin.
- The drafted runbook's **every step** carries action + verification gate +
  rollback; destructive steps are preceded by snapshot steps with a stated
  restore path.
- Step 6 report names **every point-of-no-return by step number with the last
  safe abort point before it**, prominently — this is the report's headline,
  not a footnote.
- Any `[FILL IN: …]` placeholders left in the draft are listed for the human.

## Expected Behaviors

- **Safety-first stance**: no big-bang cutovers, snapshots before destructive
  steps, canary/incremental wherever the pattern allows — a drafted runbook
  that reads like the fixture is a failure of the skill, not of the input.
- **Non-negotiables gate delivery**: any of the five at PARTIAL/MISSING ⇒
  back to the author subagent, not delivered-with-caveats.
- **Patterns compose and say so**: e.g. expand-contract for schema + canary
  for reads is one answer, with the rollback story of each stated.
- **The template is filled, not freestyled**: output follows
  RUNBOOK-TEMPLATE.md structure so two runs of the same brief are comparable.
