# jeds-curated-skills

A collection of Claude Code skills for agent-driven software development workflows.

## Installation

Clone directly to your Claude Code skills directory:

```bash
git clone https://github.com/jedarden/jeds-curated-skills ~/.claude/skills
```

Or install a single skill alongside existing ones:

```bash
git clone https://github.com/jedarden/jeds-curated-skills /tmp/jeds-curated-skills
cp -r /tmp/jeds-curated-skills/plan-review ~/.claude/skills/
```

## Skills

### `plan-review`

Pre-flight review of a software plan document before implementation begins.

Checks 80+ structural patterns across scope, acceptance criteria, architecture, safety,
phasing, testing, security, performance, operations, API design, and risk — derived from
analysis of high-quality planning documents. Catches the gaps that cause mid-implementation
pivots before any worker touches the code.

**Usage:** `/plan-review [path/to/plan.md]`

Supports greenfield, port, improvement, and integration plan types. Includes a quick triage
mode, stale-plan runbook, and multi-plan comparison runbook. After the report, offers to
draft missing sections.

## Philosophy

These skills are designed for use in headless agent workflows — they should work without
human steering mid-execution. Each skill is self-contained: it locates its own inputs,
spawns its own subagents, and produces a complete output.
