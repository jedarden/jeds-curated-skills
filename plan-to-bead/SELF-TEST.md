# Self-Test: plan-to-bead

Prose-only skill — the surface is the decomposition logic (single-task tests,
the decision filter, the coverage/scoping/dependency verification loop), not
a script. The fixture below is a planted plan.md built so each candidate task
lands on a known classification; a change to the decision filter or the
single-task tests shows up as a changed classification here.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "turn this plan into beads" | Activates |
| "decompose this plan into tasks" | Activates |
| "check my bead graph against the plan" | Activates (audit mode, repo already beaded) |
| "/plan-to-bead docs/plan/plan.md" | Activates |
| "review my plan" · "is this plan ready to implement" | Does NOT activate — that is `plan-review` (plan-to-bead may suggest it first if the plan is too thin to decompose) |

## Structure

```bash
SKILL_DIR="$HOME/.claude/skills/plan-to-bead"
ls -1 "$SKILL_DIR"              # SKILL.md SELF-TEST.md
grep -q '^allowed-tools:.*TaskCreate' "$SKILL_DIR/SKILL.md" && echo "ok: bounded-child tooling present"
grep -q 'never create a decision bead' "$SKILL_DIR/SKILL.md" && echo "ok: hard rule present"
```

## Decomposition fixture

Planted plan.md, four candidate tasks, each built to fail or pass a specific
test from the skill's own criteria:

```bash
T="$(mktemp -d)"
mkdir -p "$T/docs/plan"
cat > "$T/docs/plan/plan.md" <<'EOF'
# Plan: Digest Export Service

## Phase 1: Core

- Build the self-updater and trust pointer verification for the release binary.
- Source and commit the pinned NYSE market-calendar data file.
- Choose and pin the type checker for the TypeScript client (mypy-equivalent
  decision — strict mode has real cost tradeoffs the team hasn't weighed).
- Implement the digest renderer: parses the event batch and produces the
  formatted output.

## Open Questions

(none yet)
EOF
echo "$T" > /tmp/plan-to-bead-selftest-dir
```

**Expected classification — each candidate against the skill's own tests:**

| Candidate | Classification | Because |
|---|---|---|
| "Build the self-updater and trust pointer verification" | **BUNDLE → split into 2 beads** | Title test: "and" joins two distinct mechanisms (self-updater; trust-pointer verification) with no shared implementation step |
| "Source and commit the pinned NYSE market-calendar data file" | **Legitimate single bead** | Sourcing/committing an artifact is work, even though *which* calendar vendor was a choice — the choice itself (if still open) goes to Open Questions, not this bead |
| "Choose and pin the type checker for the TypeScript client" | **DECISION — not a bead** | Explicit "Choose X" shape; the brief names a real unresolved tradeoff (strict-mode cost) the team hasn't weighed. Must be routed to the plan's Open Questions section with a proposed answer, never created as a `DECISION:`-labeled or disguised bead |
| "Implement the digest renderer: parses the event batch and produces the formatted output" | **Legitimate single bead** | Reads as "do X" (implement the renderer); "parses... and produces" describes the one task's internal behavior, not two separable consumers or phases |

Hard pins: the type-checker candidate must **never** reach the bead graph in
any form (not `decision` label, not `DECISION:` title, not "Determine the
type checker") — if a run proposes it as a bead, that is the hard rule
violation SKILL.md's "Hard rule: never create a decision bead" section
exists to catch. The self-updater/trust-pointer candidate must split into
exactly 2 beads, not stay bundled and not split into 3+.

Then, LLM in the loop:

```
/plan-to-bead /tmp/plan-to-bead-selftest-dir/docs/plan/plan.md
```

- Step 2 detects the (nonexistent) bead backend for the fixture dir and
  either greenfield-initializes or reports blocked — confirm it does not
  guess.
- Step 3's draft matches the table above exactly: 2 split beads for the
  bundle, 1 bead each for the two legitimate candidates, 0 beads for the
  decision (plus an Open Questions entry proposing an answer).
- Step 6's independent review child receives the full graph (titles,
  descriptions, edges) and confirms no decision-shaped bead reached the
  frontier.

## Expected Behaviors

- **A decision is never a bead** — the hard rule binds drafting (Step 3),
  verification fixes (Step 6), and the genesis bead (Step 9) alike.
- **Single-task tests are applied per candidate, not just at a glance**: title
  needs "and"/plural/number word; phase-boundary; parse-vs-dispatch;
  verb-phrase. Splitting too far (an atomic task cut for no reason) is also a
  defect, not just under-splitting.
- **Dedup before drafting**: an existing bead covering a candidate is matched,
  not duplicated — a run against an already-fully-beaded repo is a pure audit.
- **Bead backend detected, never assumed** — `.beads/config.json` → bead-rs;
  `.beads/config.yaml` → legacy bf; neither present → greenfield only if
  tracking initialization is in scope.
- **Admission discipline**: unapproved proposal beads keep both `human` and
  `proposal-pending` until an explicit batch admission; turning a plan into
  beads is not blanket permission to self-admit new scope.
- **Bounded verification, not infinite rounds**: one clean required review is
  sufficient when inputs haven't changed — the loop does not spawn another
  reviewer merely to accumulate consecutive clean rounds, but does recheck
  changed nodes and their dependency impact.
- **Genesis is a fallback, created last** — a durable summary and a record of
  deliberate deferrals, never a substitute for Step 6's verification or a
  catch-all for gaps the loop should have already closed.
