---
name: migration-runbook
description: >-
  Author a reversible cutover/migration runbook — schema migration, data backfill, service
  cutover, or infra move — that a human or agent can execute step-by-step, with a verification
  gate and a rollback at every stage. Use when planning or writing a migration, cutover, or
  backfill that must be safe to abort.
argument-hint: "[brief or path to migration context]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Migration Runbook Skill

Author a migration runbook that is **reversible by construction**. Every step is an
action paired with a verification gate and a rollback. Points-of-no-return are flagged
loudly, isolated, and gated behind an explicit go/no-go. The output is a single document
a human or agent can execute top-to-bottom with confidence, aborting cleanly at any stage.

The default stance is **safety-first**: no big-bang cutovers, snapshots before destructive
steps, incremental/canary rollout, and a tested rollback path before the first irreversible action.

## Step 1: Gather Migration Context

If the user supplied a brief or a path as an argument, read it. Otherwise scan the repo for
the surfaces a migration touches:
`**/migrations/**`, `**/schema.sql`, `**/*.sql`, `**/alembic/**`, `**/flyway/**`,
`**/docker-compose*.yml`, `**/Chart.yaml`, `**/values*.yaml`, `**/config/**`, `**/terraform/**`

Establish the four facts every migration runbook needs:
1. **From → To** — what system/schema/service/dataset is moving, and to what.
2. **Downtime tolerance** — zero-downtime required, a maintenance window, or best-effort.
3. **Data volume & shape** — rows/bytes to move, backfill duration estimate, hot vs cold data.
4. **Reversibility constraints** — which steps are irreversible (data deletion, DNS/TTL,
   external-system cutover) and what the recovery-point/recovery-time objectives are.

If two or more of these are thin or unknowable from the context, use AskUserQuestion to ask
2–3 scoping questions — no more. Do not interrogate; ask only what blocks pattern selection.

## Step 2: Select a Migration Pattern

Read `~/.claude/skills/migration-runbook/references/MIGRATION-PATTERNS.md` and pick the pattern
that fits the From→To and downtime tolerance:
- **Expand-contract (parallel change)** — schema changes without downtime.
- **Dual-write + backfill** — moving data to a new store while serving live traffic.
- **Shadow / read-compare** — validating a new path against the old before trusting it.
- **Blue-green** — whole-environment swap with instant shift-back.
- **Canary** — incremental traffic shift with automated abort.
- **Strangler-fig** — incremental endpoint-by-endpoint replacement of a legacy system.

Patterns compose (e.g. expand-contract for the schema + canary for the reads). Record the
chosen pattern(s) and the rollback story each one buys you.

## Step 3: Load the Safety Checklist and Template

Read both:
- `~/.claude/skills/migration-runbook/CHECKLIST-SAFETY.md` — the bar every step must clear.
- `~/.claude/skills/migration-runbook/RUNBOOK-TEMPLATE.md` — the document structure to fill.

For zero-downtime schema changes, also read the recipe:
`~/.claude/skills/migration-runbook/runbooks/ZERO-DOWNTIME.md`

For the rollback section, pull mechanics from:
`~/.claude/skills/migration-runbook/references/ROLLBACK-PATTERNS.md`

## Step 4: Spawn the Runbook Author

Spawn the `runbook-author` subagent. Read `~/.claude/skills/migration-runbook/subagents/runbook-author.md`
for the full agent prompt. Pass it:
1. The gathered context (From→To, downtime tolerance, data volume, reversibility constraints).
2. The selected migration pattern(s) and their rollback stories.
3. The contents of `RUNBOOK-TEMPLATE.md`.
4. The contents of `references/ROLLBACK-PATTERNS.md` and, if relevant, `runbooks/ZERO-DOWNTIME.md`.
5. The output path for the runbook.

The agent fills the template so that **every step has an action, a verification gate, and a
rollback**, and every irreversible step is flagged loudly.

## Step 5: Self-Check Against the Safety Checklist

Rate the drafted runbook against every item in `CHECKLIST-SAFETY.md` as
**PRESENT / PARTIAL / MISSING**. The non-negotiables — fix before delivering if any is not PRESENT:
- Every step has a verification gate AND a rollback.
- Every destructive step is preceded by a backup/snapshot step.
- Every point-of-no-return is marked and gated behind an explicit go/no-go.
- A dry-run exists and the rollback path is tested before the first irreversible action.
- The rollout is incremental/canary — not big-bang — wherever the pattern allows.

If any non-negotiable is PARTIAL or MISSING, return to Step 4 and have the agent repair that step.

## Step 6: Write and Report

Write the runbook to the output path (default: `MIGRATION-RUNBOOK.md` beside the context, or
`./MIGRATION-RUNBOOK.md`). Then report to the user:
- The chosen pattern(s) and why.
- The safety-checklist scorecard (PRESENT / PARTIAL / MISSING counts).
- **Prominently: every point-of-no-return step**, by step number, with the latest safe abort point
  before each one.
- Any open `[FILL IN: …]` placeholders the human must resolve before executing.
