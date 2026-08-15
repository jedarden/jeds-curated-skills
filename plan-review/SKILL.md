---
name: plan-review
version: 1.0.0
description: >-
  Comprehensive pre-flight review of a software plan document to ensure no in-flight pivots
  are needed. Checks 80+ structural patterns derived from analysis of high-quality plans.
  Use before implementation begins.
argument-hint: "[path/to/plan.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion
---

# Plan Review Skill

Perform a comprehensive pre-flight review of a software plan to identify gaps that would
cause an in-flight pivot. This skill applies a checklist derived from analysis of 88
high-quality planning documents spanning CLI tools, Rust ports, web apps, and protocol
implementations.

## Step 1: Locate the Plan

If the user provided a file path as an argument, use that. Otherwise scan for:
`**/plan.md`, `**/PLAN.md`, `**/PLAN_TO_*.md`, `**/COMPREHENSIVE_PLAN*.md`,
`**/COMPREHENSIVE_SPEC*.md`, `**/ARCHITECTURE.md`, `**/design.md`

If multiple candidates exist, use AskUserQuestion.

Read the full document — at minimum all section headers plus the first 80 lines of each section.

## Step 2: Identify Plan Type

Determine which category applies — this activates type-specific checks:
- **Greenfield** — new tool/app built from scratch
- **Port** — rewriting existing code in another language or runtime
- **Improvement** — evolving an existing system
- **Integration** — connecting two existing systems

## Step 2.5: Quick Triage (Optional Fast Path)

For a quick go/no-go before committing to a full review, run:
```bash
~/.claude/skills/plan-review/scripts/score-plan.sh <plan-file>
```
If score < 40%, skip the full review and tell the user the plan needs fundamental work first.
If the user asked for a quick check only, use `runbooks/QUICK-TRIAGE.md` instead.

For stale plans (implementation already started): follow `runbooks/STALE-PLAN.md`.
For comparing two plan versions: follow `runbooks/MULTI-PLAN-COMPARISON.md`.

## Step 3: Load Checklists

First run the header scan to understand the plan's structure:
```bash
~/.claude/skills/plan-review/scripts/scan-headers.sh <plan-file>
```

Then read ALL of the following checklist files from this skill's directory
(`~/.claude/skills/plan-review/`). They contain the full review criteria:

- `CHECKLIST-01-SCOPE.md` — Document framing & scope lock
- `CHECKLIST-02-ACCEPTANCE.md` — Acceptance scenarios & success definition
- `CHECKLIST-03-ARCHITECTURE.md` — Architecture & design completeness
- `CHECKLIST-04-PREFLIGHT.md` — Pre-flight safety (the core "no pivot" checks)
- `CHECKLIST-05-PHASING.md` — Implementation phasing & gates
- `CHECKLIST-06-TESTING.md` — Testing strategy & quality gates
- `CHECKLIST-07-SECURITY.md` — Security threat model & controls
- `CHECKLIST-08-PERFORMANCE.md` — Performance budgets & benchmarks
- `CHECKLIST-09-OPERATIONS.md` — Deployment, migration & rollback
- `CHECKLIST-10-API.md` — API & interface design
- `CHECKLIST-11-RISK.md` — Risk management & fallbacks

For port plans also read: `TYPE-PORT.md`
For improvement plans also read: `TYPE-IMPROVEMENT.md`
For integration plans also read: `TYPE-INTEGRATION.md`

## Step 4: Spawn the Review Agent

Spawn the specialized deep-reviewer subagent. Read
`subagents/deep-reviewer.md` for the full agent prompt. Pass it:
1. The plan document path
2. The plan type
3. All checklist file contents
4. The `references/PIVOT-CAUSES.md` content (for diagnosing critical gaps)
5. The `references/HIGH-QUALITY-EXAMPLES.md` content (for calibrating PRESENT vs PARTIAL)

The agent rates each checklist item: **PRESENT** / **PARTIAL** / **MISSING**
with a one-line note for anything that is PARTIAL or MISSING.

## Step 5: Generate Report

Use `REPORT-TEMPLATE.md` to structure the output. The report must include:
- Summary scorecard (counts of PRESENT / PARTIAL / MISSING)
- Critical gaps in priority order
- Partial items needing strengthening
- 3–5 genuine strengths
- Top 5 recommended next steps

## Step 6: Offer to Fix

After delivering the report, ask: "Would you like me to draft the missing sections?"

If yes: spawn the `subagents/section-drafter.md` agent, passing it:
- The plan document path
- The list of MISSING and PARTIAL items to address
- The relevant checklist files for those items
- The `references/HIGH-QUALITY-EXAMPLES.md` for style reference

Prioritize Categories 1–4 before 5–11.
