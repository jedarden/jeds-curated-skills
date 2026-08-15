---
name: plan-author
version: 1.0.0
description: >-
  Generate a high-quality plan.md from a short brief or idea. Produces the eleven structural
  categories a plan-review checks for — scope lock, acceptance scenarios, architecture, pre-flight
  safety, phasing, testing, security, performance, operations, API, and risk — so the draft would
  pass review on the first pass. Use when starting a new project, port, improvement, or integration
  and you need a complete plan rather than a blank page.
argument-hint: "[brief text | path/to/brief.md] [--out path/to/plan.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Plan Author Skill

Turn a short brief into a complete `plan.md`. This skill is the inverse of `plan-review`:
it treats the eleven plan-review categories as generative targets, so the plan it writes is
already structured to pass a pre-flight review. The output is opinionated — it makes decisions
and records genuine unknowns as numbered Open Questions, never as vague "TBD".

## Step 1: Gather the Brief

The brief is the seed. Find it in this order:
1. If the argument is a readable file path, read it in full.
2. If the argument is inline prose, use it directly.
3. If no argument was given, scan for a seed: `**/README.md`, `**/docs/notes/*.md`,
   `**/IDEA.md`, `**/BRIEF.md`. Read the best candidate.

Assess whether the brief is thick enough to ground a plan. It is too thin if you cannot
answer all three of: (a) what is being built, (b) who or what consumes it, (c) what "done"
roughly means. If too thin, use AskUserQuestion to ask **at most three** scoping questions:
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

If the brief makes the type obvious, proceed. If it is genuinely ambiguous, confirm with one
AskUserQuestion. For improvement and port plans, follow the grounding flow in
`~/.claude/skills/plan-author/runbooks/FROM-EXISTING-CODE.md` first — scan the real codebase
so the plan describes what exists, not a guess.

## Step 3: Load the Template and the Completeness Bar

Read both:
- `~/.claude/skills/plan-author/PLAN-TEMPLATE.md` — the full section skeleton for all eleven
  categories, with guidance comments showing what "good" looks like per section.
- `~/.claude/skills/plan-author/CHECKLIST-COMPLETENESS.md` — the bar the finished plan must hit.

Also load, for the drafter to reference:
- `~/.claude/skills/plan-author/references/SECTION-TAXONOMY.md` — canonical headers and order.
- `~/.claude/skills/plan-author/references/EXAMPLES.md` — GOOD vs WEAK section snippets.

## Step 4: Spawn the Drafter

Spawn the `plan-drafter` subagent. Read `~/.claude/skills/plan-author/subagents/plan-drafter.md`
for the full agent prompt. Pass it:
1. The brief (and any AskUserQuestion answers)
2. The confirmed plan type
3. The contents of `PLAN-TEMPLATE.md`
4. The contents of `references/SECTION-TAXONOMY.md` and `references/EXAMPLES.md`
5. The target output path (see Step 6)
6. For port/improvement: the codebase findings from the runbook scan

The drafter writes every section, makes concrete decisions, and converts every genuine unknown
into a numbered Open Question with an owner and a resolve-by phase.

## Step 5: Self-Score and Backfill

After the drafter returns, score the draft against the completeness bar:
```bash
~/.claude/skills/plan-author/scripts/score-draft.sh <plan-file>
```
For every check reported MISSING, re-read the relevant template section and write that section
directly with the Edit tool — grounded in the plan's own components, never boilerplate. Re-run
the script until the score is at least 90%, or until the only remaining gaps are sections that
are legitimately not applicable to this plan type (note those inline as "N/A — <reason>").

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
- The single recommended next step (usually: resolve Open Questions 1–N, then run `/plan-review`).
