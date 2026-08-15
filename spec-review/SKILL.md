---
name: spec-review
version: 1.0.0
description: >-
  Pre-plan gate that reviews a product or requirements spec (PRD, requirements doc, feature
  spec) for ambiguity, untestable requirements, and missing non-functional considerations
  before a plan is authored. Quotes each vague phrase verbatim and proposes a precise rewrite.
  Use when a spec exists but no plan has been written yet, or before handing a spec to plan-author.
argument-hint: "[path/to/spec.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Spec Review Skill

Review a product or requirements specification before any plan is authored. A spec that
ships ambiguous quantifiers, untestable requirements, or undefined non-functional limits
forces the plan to guess — and every guess becomes an in-flight pivot. This skill catches
those defects while they are still cheap to fix and feeds a tightened spec into plan-author.

## Step 1: Locate the Spec

If the user provided a file path as an argument, use that. Otherwise scan for:
`**/spec.md`, `**/PRD*.md`, `**/requirements*.md`, `**/*-spec.md`, `**/feature*.md`

If multiple candidates exist, use AskUserQuestion to disambiguate.

Read the full document — every requirement, not just headers. Specs are dense; one ambiguous
clause can corrupt a whole subsystem.

## Step 2: Quick Triage (Optional Fast Path)

For a quick signal before committing to a full review, run:
```bash
~/.claude/skills/spec-review/scripts/score-spec.sh <spec-file>
```
This greps for presence of acceptance criteria, non-goals, non-functional requirements, and
success metrics. If score < 40%, tell the user the spec needs fundamental work before a full
review is worthwhile.

## Step 3: Load Checklists

Read ALL of the following checklist files from this skill's directory
(`~/.claude/skills/spec-review/`). They contain the full review criteria:

- `CHECKLIST-01-CLARITY.md` — Undefined terms, ambiguous quantifiers, hidden actors, contradictions
- `CHECKLIST-02-TESTABILITY.md` — Measurable acceptance conditions, success metrics, given/when/then
- `CHECKLIST-03-COMPLETENESS.md` — Non-functional requirements, error/edge states, data lifecycle, roles
- `CHECKLIST-04-CONSTRAINTS.md` — Assumptions, dependencies, non-goals, deadlines, compliance, open questions

## Step 4: Spawn the Review Agent

Spawn the specialized spec-reviewer subagent. Read `subagents/spec-reviewer.md` for the full
agent prompt. Pass it:
1. The spec document path
2. All checklist file contents
3. The `references/AMBIGUITY-PATTERNS.md` content (for calibrating rewrites)

The agent rates each checklist item **PRESENT** / **PARTIAL** / **MISSING** and, for every
ambiguous phrase it finds, quotes the phrase verbatim and proposes a precise rewrite.

## Step 5: Generate Report

Use `REPORT-TEMPLATE.md` to structure the output. The report must include:
- Summary scorecard (counts of PRESENT / PARTIAL / MISSING)
- Ambiguity table: quote → problem → suggested rewrite
- Missing or untestable requirements in priority order
- Clarifying questions to send back to the spec author
- 3–5 genuine strengths

## Step 6: Offer to Fix

After delivering the report, ask: "Would you like me to draft clarifying questions to send
back, or tighten the requirements in place?"

If yes, edit the spec directly — replace each quoted ambiguous phrase with its rewrite, add
the missing non-functional requirements, and append open questions for anything that needs
an author decision. Prioritize CHECKLIST-01 and CHECKLIST-02 defects before CHECKLIST-03/04.
