---
name: release-readiness
version: 1.0.0
description: >-
  Go/no-go gate run before cutting a release, tag, or deploy. Inspects the repository and
  everything changed since the last release, rates each release gate against four checklists,
  and produces an evidence-backed GO / CONDITIONAL / NO-GO verdict. Use when you are about to
  ship a version and need a final readiness check, or before tagging/deploying a release.
argument-hint: "[target-version | git-ref]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Release Readiness Skill

Run a final go/no-go gate before cutting a release. This skill inspects the repository
itself — the commits, changed files, changelog, version files, and CI config since the
last release — and produces an evidence-backed verdict. It does not take the author's word
for anything: a gate is rated PRESENT only when the evidence is found, MISSING otherwise.

The output is a single verdict — **GO**, **CONDITIONAL**, or **NO-GO** — plus the exact
list of blocking items when it is not a clean GO.

## Step 1: Establish the Release Context

Run the scan script to gather raw facts about what is being shipped:
```bash
~/.claude/skills/release-readiness/scripts/scan-release.sh
```

This reports: the last release tag, commits and changed files since that tag, any
uncommitted changes, detected CHANGELOG and version files, CI config presence, and any
leftover TODO / FIXME / debug markers in the changed files.

If the user passed a target version or git-ref as an argument, treat that as the release
under evaluation. If the working tree is dirty, note it — a release cut from a dirty tree
is itself a CONDITIONAL at best.

## Step 2: Determine the Release Type

Pick the path that applies — it changes which gates are mandatory:
- **Standard release** — planned minor/major/patch of a library or service. Full gate set.
- **Emergency hotfix** — urgent fix to a live incident. Follow
  `~/.claude/skills/release-readiness/runbooks/HOTFIX.md` for the reduced gate set.

If it is ambiguous whether this is a hotfix, use AskUserQuestion.

## Step 3: Load the Checklists

Read ALL four checklist files from this skill's directory
(`~/.claude/skills/release-readiness/`). They contain the full gate criteria:

- `CHECKLIST-01-QUALITY-GATES.md` — tests, lint, build, open P0/P1, coverage, leftover markers, dependency hygiene
- `CHECKLIST-02-VERSIONING.md` — semver bump, changelog, breaking-change docs, release notes, reproducible artifacts
- `CHECKLIST-03-OPERATIONS.md` — rollback plan, reversible migrations, feature flags, monitoring, config/secrets, runbook
- `CHECKLIST-04-COMMS-DOCS.md` — docs/README, deprecation notices, consumer notification, API reference, on-call briefing

For an emergency hotfix, load only the reduced set named in `runbooks/HOTFIX.md`.

## Step 4: Spawn the Release Auditor

Spawn the `release-auditor` subagent. Read `subagents/release-auditor.md` for the full
agent prompt. Pass it:
1. The release context from Step 1 (scan output, target version, dirty-tree status)
2. The release type from Step 2
3. The contents of all four checklist files

The agent inspects the repository for evidence and rates each gate **PRESENT** /
**PARTIAL** / **MISSING**, citing the exact file or command it checked. It marks a gate
MISSING — never PRESENT — when it cannot find evidence.

## Step 5: Generate the Go/No-Go Report

Use `REPORT-TEMPLATE.md` to structure the output. The report must include:
- The gate scorecard (counts of PRESENT / PARTIAL / MISSING per checklist)
- The verdict: **GO** / **CONDITIONAL** / **NO-GO**
- Blocking items (the exact gates that must be resolved before shipping)
- Non-blocking warnings
- Recommended pre-release actions in priority order

Verdict rules:
- **NO-GO** if any quality-gate or operations gate marked critical is MISSING.
- **CONDITIONAL** if no critical gate is MISSING but PARTIAL items or non-critical MISSING items remain.
- **GO** only when every critical gate is PRESENT and no blocking item remains.

## Step 6: If NO-GO, List the Blockers Exactly

When the verdict is NO-GO or CONDITIONAL, end with an explicit, numbered list of the
blocking items — each with the gate ID, what evidence was missing, and the concrete action
that clears it. The caller should be able to act on this list without rereading the report.
