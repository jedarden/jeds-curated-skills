# Self-Test: plan-idea-gen

Prose-only skill — an inline pipeline (explicitly **no** subagents, no
Workflow tool) over one anchored plan.md. Idea quality is judgment; the
regression shape pins the *mechanical* contract: target resolution, the
one-context rule, the ledger write, the dossier shape, and dedup against
prior runs.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "give me 10 ideas for this project" | Activates |
| "brainstorm against our plan.md" | Activates |
| "what should we build next here?" | Activates |
| "/plan-idea-gen ~/proj/docs/plan/plan.md --keep 5" | Activates |
| "implement idea #3" | Does NOT activate — this skill generates and files ideas; it does not build them |

## Structure

Single file — `SKILL.md`, no checklists/scripts/subagents:

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
ls -1 "$REPO/plan-idea-gen"   # SKILL.md and SELF-TEST.md only
for t in Agent Workflow; do
  grep -A2 '^allowed-tools:' "$REPO/plan-idea-gen/SKILL.md" | grep -q "\b$t\b" \
    && echo "FAIL: $t in allowed-tools" || echo "ok: $t not allowed"
done
```

**Structural hard pin:** `allowed-tools` omits Agent and Workflow. The
one-context rule is the skill's cost thesis; a tool-list edit that re-adds
Agent/Workflow silently defeats it.

## Fixture — minimal repo, one plan, seeded ledger

```bash
T="$(mktemp -d)" && mkdir -p "$T/proj/docs/plan" "$T/proj/docs/notes"
cat > "$T/proj/docs/plan/plan.md" <<'EOF'
# Widgetline — plan

## Purpose
Widgetline converts widget manifests to JSON fast enough to run in a
save-hook, on a cold laptop, offline.

## Hard constraints
- No network access at runtime, ever.
- Single static binary, no runtime deps beyond libc.
- Cold-start to first converted file under 50 ms.

## Open questions
- Output formatting (pretty vs compact) is undecided.
EOF
cat > "$T/proj/docs/notes/ideas-ledger.md" <<'EOF'
# Ideas ledger

## Run 2026-08-01

- mmap-the-manifests — map manifests read-only, parse in place — cluster: parsing — KILLED (violates: no mmap on all target filesystems)
EOF
echo "$T" > /tmp/pig-selftest-dir
```

## Mechanical checks (each a hard pin)

Run `/plan-idea-gen "$T/proj/docs/plan/plan.md" --pool 40 --keep 10` inside
the fixture and verify against the transcript + repo state:

1. **No subagents, no Workflow** — the transcript contains zero Agent/Task
   spawns and zero Workflow invocations. Every stage runs as inline reasoning
   passes.
2. **Single target** — exactly one plan.md is read and named; the run anchors
   GOAL/CONSTRAINTS to *its* purpose and constraints (the run should quote
   the three hard constraints, since they become kill criteria).
3. **Generation before judgment** — the full pool exists before any
   keep/cut/kill verdict appears in the transcript; no idea is revised while
   generating later ones.
4. **Dedup against PRIOR** — `mmap-the-manifests` (or a near-duplicate) is
   not re-proposed, unless the run explicitly reconsiders the recorded kill
   objection and says why it no longer holds.
5. **Ledger append** — `docs/notes/ideas-ledger.md` gains a dated section
   with **every** idea from the run (title, one-line, cluster), kill verdicts
   carrying reasons, finalists marked. The seeded run-2026-08-01 section is
   still intact above it (append, not overwrite). Repo `git log` shows the
   ledger commit using the standard jedarden identity.
6. **Dossier shape** — each finalist in the final message has: one-line pitch
   + why it won, complexity grade S/M/L, a concrete first implementation
   step, and the strongest surviving objection from the kill pass. Run stats
   (generated/deduped/triaged/killed counts) and the ledger path are present.
7. **Scale to the ask** — `--pool 40 --keep 10` yields ~40 generated; a bare
   "give me ideas" may shrink POOL; "be exhaustive" scales it up — inline in
   every case.
8. **Selection gate** — ideas become beads/plan edits only after the
   AskUserQuestion multiSelect; nothing is auto-adopted.

## Ambiguity STOP test (hard pin)

```bash
T="$(cat /tmp/pig-selftest-dir)"
mkdir -p "$T/other/docs/plan"
printf '# Two — plan\n\nAnother plan.\n' > "$T/other/docs/plan/plan.md"
# From a cwd containing BOTH $T/proj and $T/other (two candidate plan.md, no
# argument given), the skill must STOP and AskUserQuestion listing the
# candidates — never guess, never run "untargeted" ideation.
```

**Expected:** the first thing the skill does with an ambiguous target is ask.
Generating anyway, or picking a candidate silently, fails the pin — Step 0 is
marked MANDATORY for exactly this.

## Expected Behaviors

- **Lenses forced one at a time** — the pool spans the eight default lenses
  (invert-the-problem … competitor-first), `--lens` overrides; batches are
  `ceil(POOL / lenses)`.
- **Pairwise, not scores** — ranking is recorded as "A or B, because", with
  the cluster cap (**max 2 advancers per cluster**) enforced so the final set
  spans distinct territories.
- **Kill pass steelmans** — every KILL names a fatal objection; every
  survivor names the strongest objection that still stands. A survivor with
  no recorded objection did not go through Step 6.
- **Scratch durability** — pool/verdicts/survivors are appended to a scratch
  file after each stage, so a summarization-interrupted run can recover.
- **Completeness gap round** — before the final KEEP, unrepresented
  idea-space regions get one targeted batch; entrants pass the same triage +
  kill gates and may displace weaker survivors.
