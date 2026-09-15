# Self-Test: spec-review

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "review this spec" · "is this spec ready?" | Activates |
| "check my PRD for ambiguity" · "audit these requirements" | Activates |
| "is this testable?" · "what's vague in this spec?" | Activates |
| "/spec-review docs/spec.md" | Activates |
| "write the plan" | Does NOT activate — that is `plan-author` (this skill feeds it a tightened spec) |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"   # repo checkout; the installed copy at
SKILL_DIR="$REPO/spec-review"               # ~/.claude/skills/spec-review works for
                                            # structure but may lag the repo (see note)
ls -1 "$SKILL_DIR"                # 4 CHECKLIST-*.md, REPORT-TEMPLATE.md, SELF-TEST.md,
                                  # SKILL.md, references/, scripts/, subagents/
ls -1 "$SKILL_DIR/references"     # AMBIGUITY-PATTERNS.md
ls -1 "$SKILL_DIR/scripts"        # score-spec.sh
test -x "$SKILL_DIR/scripts/score-spec.sh" && echo "ok: executable"
```

Run the script tests against a **repo checkout**, not an installed copy: the scripts
source `../../lib/common.sh`, and installed copies historically lag the repo (an
installed tree without `lib/` fails to source at all).

## `score-spec.sh` fixture tests

The script greps for 13 structure signals and counts ambiguity smells. The fixtures below
have known counts — any drift means a pattern or the shared `check()`/`print_failures()`
changed. Update this table deliberately, never silently.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# --- Fixture A: mixed spec — should pass exactly 6 of 13 ---
cat > "$WORK/mixed.md" <<'EOF'
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
"$REPO/spec-review/scripts/score-spec.sh" "$WORK/mixed.md"
echo "exit=$?"
```

**Expected (Fixture A):**

```
Structure score: 6 / 13 (46%)
Status: NEEDS TIGHTENING (run the full review)
```

MISSING exactly: `Security NFR`, `Scale / capacity`, `Data lifecycle`,
`Roles / permissions`, `Assumptions`, `Dependencies`, `Open questions`.

```
--- Ambiguity Smells (count of vague terms) ---
  fast                   1

Total ambiguity smells: 1 (each should be quoted and rewritten in the review)
```

- Passes: Acceptance criteria (`acceptance scenario`, `pass/fail`), Success metrics
  (`success metric`, `p95`, `latency`, `throughput`), Non-goals (`out of scope`),
  Performance (`performance`, `latency`, `load`), **Error / edge states via `error budget`
  — an incidental substring hit**, and **Constraints via `budget`** — the single-word
  patterns are triage heuristics and do match incidentally. If you tighten them to
  word-boundaries, that is a scoring-logic change: re-pin this fixture, don't paper over it.
- The one smell: `fast` matched inside **faster** (`burns 2x faster`). Smell terms are
  substring matches, not word matches.

```bash
# --- Fixture B: complete spec — 13/13, empty failures section ---
cat > "$WORK/complete.md" <<'EOF'
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
"$REPO/spec-review/scripts/score-spec.sh" "$WORK/complete.md"
```

**Expected (Fixture B):** `Structure score: 13 / 13 (100%)`,
`Status: READY FOR PLANNING (minor gaps only)`, **no MISSING lines at all** (exercises the
empty-failures branch of `print_failures`), and `Total ambiguity smells: 0` — the fixture
deliberately avoids every smell term, including inside other words.

```bash
# --- Fixture C: thin spec — 0/13 ---
printf '# Spec: Widget\n\nWe will build a widget.\n' > "$WORK/thin.md"
"$REPO/spec-review/scripts/score-spec.sh" "$WORK/thin.md" | grep -E 'score|Status'
```

**Expected (Fixture C):** `Structure score: 0 / 13 (0%)` and
`Status: NOT READY (fundamental gaps — fix before a full review is worthwhile)`, followed by
all 13 MISSING lines in checklist order.

```bash
# --- Usage errors ---
"$REPO/spec-review/scripts/score-spec.sh"; echo "exit=$?"              # exit=1
"$REPO/spec-review/scripts/score-spec.sh" "$WORK/nope.md"; echo "exit=$?"  # exit=1
```

Both print `Usage: score-spec.sh <spec-file>` to stderr. Successful runs always exit 0 —
a low score is a report, not a failure.

## Functional Test (LLM in the loop)

Run `/spec-review` on Fixture A above. Expected:

- Each vague phrase is quoted **verbatim** with a proposed precise rewrite (e.g. the
  unspecified "stated budget" becomes a number with a measurement condition).
- The missing sections are listed with why each blocks planning (no roles → who is the actor
  in every scenario?).
- Untestable requirements are called out: anything without a pass/fail condition.
- The output follows REPORT-TEMPLATE.md and ends with a tightened-spec handoff to
  `plan-author`.

## Expected Behaviors

- **Triage, not judgment**: the script's job is a fast signal (< 40% → don't bother with a
  full review yet). It cannot judge whether the acceptance criteria are *good*.
- **Exit codes**: 0 on any successful scan (regardless of score), 1 on usage error.
- **Case-insensitive, substring matching** everywhere — see the `error budget`/`faster`
  notes above.
- **Counts are per-occurrence**: two `etc` on one line count as 2 smells (`grep -o`).
