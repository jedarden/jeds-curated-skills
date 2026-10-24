---
name: plan-author
metadata:
  version: "1.1.1"
description: >-
  Generate a high-quality plan.md from a short brief or idea. Produces the eleven structural
  categories a plan-review checks for — scope lock, acceptance scenarios, architecture, pre-flight
  safety, phasing, testing, security, performance, operations, API, and risk — so the draft would
  pass review on the first pass, including the review's safety caps: a Phase 0 that exercises the
  riskiest real dependency on demand, a named test oracle other than production, an inner-loop
  check budget, and one shippable type per plan (a compound brief is split, not merged). Use when
  starting a new project, port, improvement, integration, migration/cutover, or spike and you need
  a complete plan rather than a blank page.
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Plan Author Skill

Invocation: provide brief text or a path to a brief; optionally specify `--out <plan-path>`.
Resolve relative resource paths below from this skill's directory, wherever it is installed.
Use the current environment's file, shell, question, and delegation capabilities. The
frontmatter tool list is retained for Claude Code.

Turn a short brief into a complete `plan.md`. This skill is the inverse of `plan-review`:
it treats the eleven plan-review categories as generative targets, so the plan it writes is
already structured to pass a pre-flight review. The output is opinionated — it makes decisions
and records genuine unknowns as numbered Open Questions, never as vague "TBD". Migration/cutover
plans get explicit safety controls, while spikes get a bounded experiment and decision protocol.

## Step 1: Gather the Brief

The brief is the seed. Find it in this order:
1. If the argument is a readable file path, read it in full.
2. If the argument is inline prose, use it directly.
3. If no argument was given, scan for a seed: `**/README.md`, `**/docs/notes/*.md`,
   `**/IDEA.md`, `**/BRIEF.md`. Read the best candidate.

Assess whether the brief is thick enough to ground a plan. It is too thin if you cannot
answer all three of: (a) what is being built, (b) who or what consumes it, (c) what "done"
roughly means. If too thin, ask **at most three** scoping questions:
the core mission, the single most important hard constraint, and the primary consumer/interface.
Do not interrogate beyond three — fill remaining gaps as Open Questions in the plan itself.

## Step 2: Detect and Confirm Plan Type

Classify the work — this changes which sections get emphasis:
- **Greenfield** — new tool/app from scratch (emphasis: acceptance scenarios, walking skeleton)
- **Port** — reimplementing existing code in another language/runtime (emphasis: parity matrix,
  conformance harness, source metrics)
- **Improvement** — evolving a running system (emphasis: gap inventory, what-we're-NOT-changing,
  regression tests, rollback-before-rollout)
- **Integration** — wiring two existing systems together (emphasis: per-dependency contracts,
  failure isolation, rollback coordination)
- **Migration / Cutover** — moving data, users, or traffic (emphasis: backup and restore rehearsal,
  idempotent/resumable steps, shadow/canary comparison, and a named cutover rollback trigger)
- **Spike** — an experiment whose deliverable is a decision (emphasis: question, metrics and
  thresholds, environment, time box, decision record, and default if inconclusive)

If the brief makes the type obvious, proceed. If it is genuinely ambiguous, confirm with one
question. For improvement, port, and migration/cutover plans, follow the grounding flow in
`runbooks/FROM-EXISTING-CODE.md` first — scan the real codebase
so the plan describes what exists, not a guess.

**A compound brief gets one plan per shippable type, never one plan for all of them.** A brief
that asks to port a running system *and* migrate its data *and* integrate a second system *and*
add new capabilities is four plans wearing one title. Written as one plan it is fully decidable,
fully gated, and undeliverable: nothing ships until everything does, and plan-review trips Cap
C8 on it. Pick the type that ships first — the slice that retires or shadows **one** legacy
capability through the real dependency — and write *that* plan. Record the other workstreams in
§2 Non-Goals as **held**, each with the entry gate that opens it (usually "after Phase N of this
plan is accepted"), and offer to author their plans afterwards. Say which type you chose and why
in the report. Only when the user explicitly insists on a single document do you write one, and
then the type is the first-shipping type, the held workstreams appear only as held non-goals
with gates, and the phase table covers only the chosen type.

**Scope has a consequence.** For a Port, the source metrics from the runbook scan are not a
footnote: a plan that ports 150k lines before retiring any legacy path is a parity treadmill.
Every phase after Phase 0 names the one legacy capability it retires or shadows and a size cap;
§2 names what is explicitly *not* ported.

## Step 3: Load the Template and the Completeness Bar

Read both:
- `PLAN-TEMPLATE.md` — the full section skeleton for all eleven
  categories, with guidance comments showing what "good" looks like per section and a conditional
  type-specific control block for Port, Migration / Cutover and Spike.
- `CHECKLIST-COMPLETENESS.md` — the bar the finished plan must hit.

Also load, for the drafter to reference:
- `references/SECTION-TAXONOMY.md` — canonical headers and order.
- `references/EXAMPLES.md` — GOOD vs WEAK section snippets.

## Step 4: Spawn the Drafter

Spawn a `plan-drafter` subagent through the current environment's delegation mechanism. Read
`subagents/plan-drafter.md` for its full prompt. Pass it:
1. The brief (and any scoping answers)
2. The confirmed plan type
3. The contents of `PLAN-TEMPLATE.md`
4. The contents of `references/SECTION-TAXONOMY.md` and `references/EXAMPLES.md`
5. The target output path (see Step 6)
6. For port/improvement: the codebase findings from the runbook scan

The drafter writes every section, makes concrete decisions, and converts every genuine unknown
into a numbered Open Question with an owner and a resolve-by phase.
If delegation is unavailable, follow the same prompt yourself.

## Step 5: Self-Score and Backfill

After the drafter returns, score the draft against the completeness bar:
```bash
bash <skill-directory>/scripts/score-draft.sh <plan-file>
```
For every check reported MISSING, re-read the relevant template section and write that section
directly in the file — grounded in the plan's own components, never boilerplate. For a
Port, Migration / Cutover or Spike, the scorer adds the applicable type-specific checks; do not
treat those controls as optional. Three base checks are the ones a review's caps hinge on and
are never satisfied by writing the words: 6.4 (Phase 0 exercises the riskiest real dependency,
re-runnable without a production event), 7.3 (a test oracle other than production, as a
command) and 7.4 (an inner-loop check bounded in minutes). If the honest answer to 7.3 is
"only production", the plan is not ready and §16 must carry the question of how to build the
oracle before Phase 0 — do not paper over it. Re-run the script until the score is at least 90%, or until the only
remaining gaps are sections that are legitimately not applicable to this plan type (note those
inline as "N/A — <reason>").

## Step 6: Write the File and Report

Determine the output path:
- If `--out <path>` was passed, use it.
- Else if a `docs/plan/` directory exists in the working tree, write `docs/plan/plan.md`.
- Else write `plan.md` in the working directory.

Write the final plan. Then report:
- The output path and final completeness score.
- Which sections were **generated with concrete decisions** vs. **left as Open Questions**
  (list the numbered Open Questions so the user knows exactly what still needs a human call).
- Any sections marked N/A and why.
- The single recommended next step (usually: resolve Open Questions 1–N, then invoke `plan-review`).
