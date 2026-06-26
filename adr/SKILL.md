---
name: adr
description: >-
  Author a new Architecture Decision Record or review existing ones for quality. Drafts a
  numbered ADR with steel-manned alternatives and honest consequences, or rates an ADR against
  a quality checklist and flags strawman alternatives and missing negatives.
  Use when capturing a design decision, writing an ADR, or auditing existing decision records.
argument-hint: "[author|review] [decision brief | path/to/adr]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# ADR Skill

Author or review Architecture Decision Records. An ADR captures one architectural decision:
the forces at play, the choice made, the alternatives genuinely weighed, and the consequences —
including the negative ones. A good ADR is honest about what becomes harder.

This skill runs in one of two modes. Determine the mode first, then follow the matching steps.

## Step 1: Determine Mode

- **author** — the input is a decision brief, a question, or a description of a choice to record.
  Produce a new numbered ADR file.
- **review** — the input is a path to an existing ADR file or a directory of ADRs.
  Rate quality and emit a report.

If the argument names a mode, use it. Otherwise infer: a path to an existing `.md` ADR ⇒ review;
a decision description ⇒ author. If genuinely ambiguous, use AskUserQuestion.

## Step 2: Locate the ADR Directory

Glob for an existing ADR home, in priority order:
`**/docs/adr/`, `**/doc/adr/`, `**/adr/`, `**/decisions/`, `**/docs/decisions/`

- **review mode** — if the input is a single file, use it directly. If it is a directory,
  collect every `*.md` ADR inside (skip `README.md` and `template.md`).
- **author mode** — if a directory exists, compute the next sequence number from the highest
  `NNNN-*.md` prefix already present (e.g. existing `0007-…` ⇒ next is `0008`). If no ADR
  directory exists, create `docs/adr/` and start at `0001`. Use 4-digit zero-padded numbers.

If multiple candidate directories exist, use AskUserQuestion to pick one.

## Step 3: Load Template and Checklist

Read both supporting files from this skill's directory (`~/.claude/skills/adr/`):

- `~/.claude/skills/adr/ADR-TEMPLATE.md` — the canonical ADR structure
- `~/.claude/skills/adr/CHECKLIST-QUALITY.md` — the quality bar

For calibration, also read `~/.claude/skills/adr/references/EXAMPLES.md` — one strong and one
weak worked ADR.

## Step 4: Run the Mode

### Author mode

Spawn the `adr-author` subagent. Read `~/.claude/skills/adr/subagents/adr-author.md` for the
full agent prompt. Pass it:
1. The decision brief / context provided by the user
2. The computed target file path (e.g. `docs/adr/0008-use-cursor-pagination.md`)
3. The contents of `ADR-TEMPLATE.md`
4. The contents of `CHECKLIST-QUALITY.md` (so the draft satisfies the bar)
5. The contents of `references/EXAMPLES.md` (for style and the steel-man standard)

The agent writes the ADR file. If the decision supersedes an earlier ADR, it also updates the
superseded ADR's status line and adds the reciprocal link (see Step 5).

### Review mode

Spawn the `adr-reviewer` subagent. Read `~/.claude/skills/adr/subagents/adr-reviewer.md` for the
full agent prompt. Pass it:
1. The list of ADR file paths to review
2. The contents of `CHECKLIST-QUALITY.md`
3. The contents of `references/EXAMPLES.md` (for calibrating PRESENT vs PARTIAL)
4. The contents of `~/.claude/skills/adr/REPORT-TEMPLATE.md`

The agent rates each ADR item: **PRESENT** / **PARTIAL** / **MISSING**, flags strawman
alternatives and missing negative consequences, and emits one report per ADR (or a combined
report for a directory).

## Step 5: Finalize

- **author mode** — confirm the file was written and report the path and chosen sequence number.
  If an ADR was superseded, confirm both the new ADR's `Supersedes:` link and the old ADR's
  `Status: Superseded by NNNN` line and `Superseded-by:` link were set. Supersession links must
  be reciprocal — never one-directional.
- **review mode** — deliver the report(s) using `REPORT-TEMPLATE.md`. Offer:
  "Would you like me to draft strengthened versions of the weak sections?" If yes, run author
  mode against the same file to rewrite the flagged sections in place (preserving number and date).
