---
name: test-plan-review
description: >-
  Suite-level review of an existing test directory or a test-plan document. Finds coverage
  gaps and tests that will lie to you — what isn't being tested, and which tests pass for the
  wrong reasons. Use when you have a tests/ tree or a TESTING.md and want to know what's missing
  before trusting the suite.
argument-hint: "[path/to/tests-or-test-plan]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Test Plan Review Skill

Review a test SUITE or a test PLAN at the suite level — not line by line. The question this
skill answers: **what behavior isn't being tested, and which tests will pass even when the
code is broken?** A green suite that doesn't exercise the failure paths is worse than no
suite, because it manufactures false confidence.

## Step 1: Locate the Inputs

If the user provided a path as an argument, use it. Otherwise discover the target:

**Test-plan document** — glob: `**/test-plan*.md`, `**/TEST-PLAN*.md`, `**/TESTING.md`,
`**/test_plan*.md`

**Test directory / files** — glob: `**/tests/`, `**/__tests__/`, `**/*_test.*`,
`**/*.test.*`, `**/test_*.*`, `**/*_spec.*`, `**/*.spec.*`

If both a plan doc and a test tree exist, review both (the plan states intent; the tree shows
reality — gaps between them are findings). If multiple unrelated candidates exist, use
AskUserQuestion to disambiguate.

## Step 2: Inventory the Tests

Run the scanner to build a picture of what exists before judging what's missing:
```bash
~/.claude/skills/test-plan-review/scripts/scan-tests.sh <repo-or-tests-dir>
```
This counts test functions per file, identifies the test framework(s), and — most importantly
— reports which source directories have **no corresponding tests**. Those are your first
coverage suspects.

## Step 3: Load Checklists

Read ALL of the following checklist files from this skill's directory
(`~/.claude/skills/test-plan-review/`). They contain the full review criteria:

- `CHECKLIST-01-COVERAGE.md` — boundaries, paths, entry points, branch coverage, cardinality
- `CHECKLIST-02-FAILURE.md` — failure injection, error paths, timeouts, dependency-down
- `CHECKLIST-03-NONFUNCTIONAL.md` — concurrency, idempotency, ordering, cleanup, persistence
- `CHECKLIST-04-QUALITY.md` — determinism, isolation, meaningful assertions, over-mocking

Also read `references/MISSING-TEST-PATTERNS.md` — the catalog of commonly-missed test
categories used to name specific gaps rather than vague "needs more coverage."

## Step 4: Spawn the Review Agent

Spawn the `test-reviewer` subagent. Read `subagents/test-reviewer.md` for the full agent
prompt. Pass it:
1. The target path(s) — test plan doc and/or test directory
2. The scanner output from Step 2
3. All four checklist file contents
4. The `references/MISSING-TEST-PATTERNS.md` content

The agent rates each checklist item **PRESENT** / **PARTIAL** / **MISSING**, and for every
PARTIAL or MISSING item names a **specific untested behavior** and **the bug that test would
catch**. Generic findings are rejected.

## Step 5: Generate Report

Use `REPORT-TEMPLATE.md` to structure the output. The report must include:
- Summary scorecard (counts of PRESENT / PARTIAL / MISSING per category)
- Coverage-gap table: untested behavior → risk → suggested test
- Flaky / weak-test findings (tests that pass for the wrong reason)
- Top tests to add, ordered by value
- 3–5 genuine strengths

## Step 6: Offer to Draft the Missing Tests

After delivering the report, ask: "Want me to draft the highest-value missing test cases?"

If yes: write skeletons for the top gaps using the project's existing test framework and
conventions (match an existing test file's style). Each skeleton states arrange/act/assert
and the exact behavior under test in a comment. Do not invent assertions you cannot ground in
the code — leave a `TODO` where the expected value must be confirmed.
