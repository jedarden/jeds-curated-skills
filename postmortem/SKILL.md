---
name: postmortem
version: 1.0.0
description: >-
  Author a blameless incident postmortem from an incident description and any available
  artifacts (logs, timeline notes, chat transcripts), or review an existing draft for
  blameless tone and analytical depth. Builds a timestamped timeline, quantified impact,
  contributing-factor analysis, and owned action items. Use when an incident is resolved
  and needs a written retrospective, or when a draft postmortem needs a quality pass.
argument-hint: "[incident summary or path/to/draft.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Postmortem Skill

Produce a complete blameless incident postmortem. The goal is organizational learning,
not attribution. Every finding targets systems and process — never people. Impact is
quantified, the timeline includes detection and each mitigation attempt, analysis goes
beyond a single root cause to contributing factors, and every action item has an owner,
a due date, and a prevent/detect/mitigate classification.

This skill operates in two modes:
- **Author mode** (default) — construct a postmortem from an incident description and artifacts.
- **Review mode** — rate an existing draft against the quality checklist and suggest fixes.

## Step 1: Determine Mode and Gather Inputs

If the argument is a path to an existing markdown file that already contains postmortem
sections (summary, timeline, root cause), enter **Review mode** — skip to Step 5.

Otherwise enter **Author mode**. Collect what you can without asking the user:
- The incident summary from the argument or the conversation brief.
- Any artifact paths mentioned (log files, timeline notes, chat transcripts, alert exports).
  Read or `grep` them for timestamps, error signatures, deploy markers, and alert fire/resolve times.
- Scan the working directory for obvious artifacts: `*.log`, `incident*.md`, `timeline*`,
  `*.json` alert exports.

Only ask the user (via AskUserQuestion, 2-3 questions max) if the **core facts are missing**:
what broke, when it started and ended, and the user-facing impact. Do not interrogate for
detail the artifacts can supply.

## Step 2: Load the Template and Checklist

Read both of these from this skill's directory (`~/.claude/skills/postmortem/`):
- `POSTMORTEM-TEMPLATE.md` — the document structure to produce.
- `CHECKLIST-QUALITY.md` — the bar the finished document must clear.

## Step 3: Load the References

Read both reference files so the analysis is blameless and deep:
- `~/.claude/skills/postmortem/references/BLAMELESS-GUIDE.md` — before/after phrasing
  to convert person-blame into systemic statements.
- `~/.claude/skills/postmortem/references/CONTRIBUTING-FACTORS.md` — common factor
  categories to prompt analysis past the first cause.

## Step 4: Spawn the Postmortem Author

Spawn the `subagents/postmortem-author.md` agent. Pass it:
1. The incident summary and all gathered facts.
2. The artifact paths (so it can read them directly for timestamps and signatures).
3. The contents of `POSTMORTEM-TEMPLATE.md`.
4. The contents of both reference files.

The agent builds the timeline, quantifies impact, runs a causal-chain / 5-whys analysis
to surface contributing factors, and drafts concrete owned action items.

## Step 5: Self-Check Against the Quality Checklist

Rate the draft (the author's output, or the user's draft in Review mode) against every
item in `CHECKLIST-QUALITY.md`: **PRESENT / PARTIAL / MISSING**. Pay special attention to:
- Blameless language — no name used as blame, no "human error" as a terminal cause.
- Impact is quantified (users, duration, SLO/error budget, revenue where known).
- Timeline includes detection time and each mitigation attempt, not just start and end.
- Analysis names contributing factors beyond one root cause.
- Every action item has an owner, a due date, and a prevent/detect/mitigate type.
- No action item is merely "be more careful" or "pay more attention."
- A "where we got lucky" section is present.

Fix every PARTIAL and MISSING item before writing the final document.

## Step 6: Write or Report

**Author mode:** Write the finished postmortem to a file (default
`POSTMORTEM-<short-slug>.md` in the working directory, or a path the user specified).
Then report the scorecard and the action-item list.

**Review mode:** Do not overwrite the user's draft. Report the checklist scorecard,
the specific blameless-tone violations with suggested rewrites, the analytical gaps,
and any action items missing an owner/date/type. Offer to apply the fixes.
