# Self-Test: postmortem

Prose-only skill — two surfaces: the review checklist
(`CHECKLIST-QUALITY.md`, 14 items) and the author flow, whose CandidateLesson
step is **mechanically verifiable** (content-hash IDs, fixed output path). The
regression shape: a fixture draft that fails nearly everything, plus a hash
check any shell can re-run.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "write the postmortem for yesterday's outage" | Activates, author mode |
| "review this postmortem draft" | Activates, review mode |
| "make this retro blameless" | Activates, review mode |
| "/postmortem incident-2026-09-14.md" | Activates, review mode (existing .md with postmortem sections) |
| "add this to the on-call rotation" | Does NOT activate |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SKILL_DIR="$REPO/postmortem"
ls -1 "$SKILL_DIR"              # CHECKLIST-QUALITY.md, POSTMORTEM-TEMPLATE.md,
                                # SELF-TEST.md, SKILL.md, references/,
                                # subagents/, templates/
ls -1 "$SKILL_DIR/references"   # BLAMELESS-GUIDE.md, CONTRIBUTING-FACTORS.md
ls -1 "$SKILL_DIR/templates"    # lesson.md
ls -1 "$SKILL_DIR/subagents"    # postmortem-author.md
```

## Review-mode fixture

A deliberately bad draft with a planted violation for nearly every checklist
item, annotated inline:

```bash
T="$(mktemp -d)"
cat > "$T/incident-2026-09-14.md" <<'EOF'
# Outage postmortem — 2026-09-14

## Summary

Alice deployed the billing service on Friday afternoon and took the site
down. (planted: 1.1 person-blame) It was human error — someone forgot to run
the migration. (planted: 1.2 human-error terminal cause) Lots of users were
very upset. (planted: 1.3 adjectives, no numbers)

## Timeline

- 16:02 deploy started
- 16:41 service restored (planted: 1.5 — no detection event, no failed
  mitigation attempts; 1.4 — no detection info at all)

## Root cause

Root cause: Alice. (planted: 1.6 single-line cause, no chain; 1.7 no
contributing-factor categories)

## Action items

- Be more careful around deploys. (planted: 1.11 exhortation)
- Alice will look into it. (planted: 1.10 no due date, no type)

(planted: 1.8 no what-went-well; 1.9 no got-lucky; 1.12 no generalized
lessons; 1.13 no CandidateLesson record; 1.14 "logs are attached" — nothing
attached)
EOF
echo "$T" > /tmp/pm-selftest-dir
```

**Expected inventory — `/postmortem <fixture>` (review mode):**

| Item | Rating | Because (the planted defect) |
|------|--------|------------------------------|
| 1.1 Blameless language | MISSING | Alice named as the cause |
| 1.2 No "human error" terminal | MISSING | "someone forgot" ends the analysis |
| 1.3 Impact quantified | MISSING | "lots of users, very upset" |
| 1.4 Detection captured | MISSING | Nothing about how it was detected |
| 1.5 Timeline includes detection + mitigations | PARTIAL | Timestamps exist (start/end) but no detection event, no mitigation attempts |
| 1.6 Beyond a single root cause | MISSING | "Root cause: Alice." |
| 1.7 Contributing factors by category | MISSING | None considered |
| 1.8 What went well | MISSING | Absent |
| 1.9 Where we got lucky | MISSING | Absent |
| 1.10 Action items owner+date+type | MISSING | Neither item complete |
| 1.11 No "be more careful" | MISSING | Literally present |
| 1.12 Lessons generalize | MISSING | Absent |
| 1.13 CandidateLesson record | MISSING | Absent |
| 1.14 Evidence references resolve | MISSING | "logs are attached", nothing attached |

Hard pins: 1.1, 1.2, 1.11 are grep-able — the review must quote the violating
line and propose a rewrite from references/BLAMELESS-GUIDE.md (e.g. "the
deploy pipeline allowed a migration-less deploy"). Totals **0 PRESENT /
1 PARTIAL / 13 MISSING**; review mode must **not overwrite** the draft and
must offer the fixes. A review that returns "mostly fine" on this fixture has
lost the checklist.

## Author-mode checks

Feed the skill a brief plus an artifact with planted timestamps:

```bash
T="$(cat /tmp/pm-selftest-dir)"
cat > "$T/deploy.log" <<'EOF'
2026-09-14T15:58:00Z ci: billing 2.14.0 queued
2026-09-14T16:02:11Z ci: billing 2.14.0 deployed
2026-09-14T16:07:30Z alert: p99 latency > 5s (billing-checkout)
2026-09-14T16:12:00Z page: oncall ack
2026-09-14T16:19:44Z rollback attempted: 2.13.9 — failed, migration mismatch
2026-09-14T16:31:02Z forward-fix: migration applied manually
2026-09-14T16:41:00Z recovery confirmed, all clear
EOF
```

**Expected:** the timeline includes 16:07 (detection), the **failed** 16:19
rollback attempt as well as the 16:31 fix; impact is quantified or labeled as
an estimate; analysis names ≥ 2 contributing factors beyond the trigger
(missing pre-deploy migration gate, alert-only detection, rollback untested
against migration drift); every action item has owner + due date +
prevent/detect/mitigate; "where we got lucky" names something real (e.g.
failed rollback surfaced the migration mismatch before data divergence).

### CandidateLesson mechanics (shell-verifiable)

Run author mode with the fingerprint and scope prescribed in the brief so the
hash is recomputable: fingerprint
`deploy-without-migration:billing-service:missing-migration-gate`, scope
`service:billing`. The ID is the first 16 hex of `sha256(fingerprint + scope)`
— plain concatenation, no separator (SKILL.md Step 7):

```bash
T="$(cat /tmp/pm-selftest-dir)"
FP="deploy-without-migration:billing-service:missing-migration-gate"
SC="service:billing"
EXPECTED_ID="$(printf '%s' "${FP}${SC}" | sha256sum | cut -c1-16)"
echo "expected lesson id: $EXPECTED_ID"

LESSON="$T/docs/notes/lessons/$EXPECTED_ID.md"
[ -f "$LESSON" ] && echo "PASS: lesson at content-hash path" \
                 || echo "FAIL: expected $LESSON (got: $(ls "$T"/docs/notes/lessons/ 2>/dev/null))"

# Frontmatter completeness — real field names from templates/lesson.md:
for k in id failure_fingerprint evidence_references proposed_rule_text \
         proposed_gate_or_hook_change scope expiry severity status; do
  grep -q "^$k:" "$LESSON" || echo "FAIL: frontmatter missing $k"
done
grep -q "^id: \"$EXPECTED_ID\"" "$LESSON" \
  && echo "PASS: id field matches filename" || echo "FAIL: id field mismatch"
grep -q "$FP" "$LESSON" && echo "PASS: fingerprint recorded verbatim" \
                        || echo "FAIL: fingerprint not found"
grep -q "\"$SC\"" "$LESSON" && echo "PASS: scope recorded" || echo "FAIL: scope not found"

# Evidence references resolve — the postmortem path must exist:
grep -oE '(postmortem|log): *"?[^"]*\.md"?' "$LESSON" | grep -oE '/[^ "]*\.md' | while read -r p; do
  [ -e "$T$p" ] && echo "ok: $p" || echo "FAIL: dangling evidence $p"
done

# Idempotency: re-running the same incident yields the same ID and appends
# evidence rather than duplicating the file.
ls "$T/docs/notes/lessons/" | wc -l   # expect 1 after a re-run
```

**Expected:** `PASS` on the hash and id-field checks, no `FAIL` lines, lesson
path exactly `docs/notes/lessons/<id>.md` — nowhere else. **Idempotency:**
re-running produces the same ID; the existing file gains appended evidence,
not a duplicate (count stays 1).

## Expected Behaviors

- **Mode inference**: an existing .md with postmortem sections ⇒ review; a
  description ⇒ author; core facts missing (what broke, when, user impact) ⇒
  at most 2–3 AskUserQuestion questions — artifacts are read, not asked for.
- **Blameless conversion is mechanical, not vibes**: person-blame sentences
  come back as system statements ("the deploy pipeline allowed X"), citing
  BLAMELESS-GUIDE.md before/after pairs.
- **Failed mitigation attempts appear** — a timeline that only shows what
  finally worked fails 1.5 even if every timestamp is real.
- **Lessons land in the target repo only** (`docs/notes/lessons/`), and the
  report states count, paths, fingerprints — never the rule text as a
  to-do-that-nobody-owns; the proposed gate names the hook/CI check
  concretely.
