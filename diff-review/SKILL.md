---
name: diff-review
version: 1.0.0
description: >-
  Language-agnostic structural review of a code diff for correctness bugs and design/cleanup
  issues, with an adversarial verification pass that suppresses false positives. Collects the
  diff itself via git, spawns its own reviewers, and emits a severity-ordered report.
  Use when you want a self-contained, high-confidence review of staged, working-tree, or
  branch changes before they land.
argument-hint: "[base-ref]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Diff Review Skill

Perform a correctness-first review of a code diff. This skill is opinionated: it biases toward
a small set of high-confidence findings and runs an adversarial verifier to drop anything it
cannot substantiate from the diff. A clean diff should produce few or zero findings — silence
is a valid result, noise is not.

## Step 1: Collect the Diff

Run the collector to resolve a base ref and produce the unified diff plus a changed-files
summary:

```bash
~/.claude/skills/diff-review/scripts/collect-diff.sh [base-ref]
```

Resolution order when no `base-ref` argument is given:
1. Merge-base of `HEAD` with the default branch (`origin/HEAD`, then `main`, then `master`).
2. Staged changes (`git diff --cached`) if no upstream base resolves.
3. Working-tree changes (`git diff`) as the last fallback.

If the repo has multiple plausible base branches and the choice is ambiguous, use
AskUserQuestion to confirm the base ref. Otherwise proceed with the resolved default.

Note the total changed-line count from the summary. If it exceeds ~800 lines, follow
`~/.claude/skills/diff-review/runbooks/LARGE-DIFF.md` instead of the single-pass flow below.

## Step 2: Load Checklists

Read ALL of the following checklist files from this skill's directory
(`~/.claude/skills/diff-review/`). They define the review criteria:

- `CHECKLIST-01-CORRECTNESS.md` — logic errors, boundaries, null handling, error paths, leaks, races, API misuse
- `CHECKLIST-02-DESIGN.md` — duplication, leaky abstractions, complexity, naming, dead code, compat breaks
- `CHECKLIST-03-TESTS.md` — coverage of changed behavior, new branches, meaningful assertions, failure paths
- `CHECKLIST-04-SECURITY.md` — injection, unvalidated input, secrets, authz, unsafe deserialization, path traversal

## Step 3: Spawn the Diff Reviewer

Spawn the `diff-reviewer` subagent. Read `~/.claude/skills/diff-review/subagents/diff-reviewer.md`
for the full agent prompt. Pass it:
1. The unified diff and changed-files summary from Step 1
2. The contents of all four checklist files

The agent produces **candidate findings**. Each candidate MUST carry: `file:line`, a severity
(Blocking / Should-fix / Nit), the checklist item it maps to, and a concrete one-to-two sentence
"why it's wrong" grounded in the diff. Candidates without a concrete failure mechanism are not
emitted.

## Step 4: Adversarially Verify

Spawn the `finding-verifier` subagent. Read
`~/.claude/skills/diff-review/subagents/finding-verifier.md` for the full prompt. Pass it:
1. The candidate findings from Step 3
2. The same unified diff (and, if needed, file paths so it can read surrounding context)

The verifier tries to **refute** each finding. It defaults to REFUTED when it cannot prove the
finding from the diff plus the immediately surrounding code. Only findings it marks CONFIRMED
survive. Drop everything else.

## Step 5: Emit the Report

Use `~/.claude/skills/diff-review/REPORT-TEMPLATE.md` to structure the output. Include only
surviving (CONFIRMED) findings, grouped by severity (Blocking / Should-fix / Nit) and ordered
within each group. Each finding shows `file:line`, the explanation, and a concrete suggested fix.
End with the one-line verdict: **approve** / **approve-with-nits** / **request-changes**.

If no findings survive, say so plainly and return the **approve** verdict — do not manufacture
nits to fill space.
