---
name: threat-model
description: >-
  Produce or review a STRIDE-based threat model for a system. Enumerates assets, trust
  boundaries, data flows, and entry points, then walks STRIDE per element to emit a threat
  model document with mitigations — or rates an existing model's coverage and finds gaps.
  Use when you need a threat model authored from an architecture/design doc or codebase, or
  when an existing threat model needs a coverage audit.
argument-hint: "[author|review] [path/to/architecture-or-threat-model.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Threat Model Skill

Produce or review a STRIDE-based threat model. STRIDE walks every data-flow element through
six threat categories — Spoofing, Tampering, Repudiation, Information disclosure, Denial of
service, Elevation of privilege — so that no element is left unexamined. The skill runs
headless: it locates its own inputs, spawns its own subagent, and emits a complete document
or coverage report.

## Step 1: Determine Mode

Two modes:
- **AUTHOR** — build a new threat model from an architecture/design doc or codebase.
- **REVIEW** — rate an existing threat model's coverage and find gaps.

If the first argument is `author` or `review`, use it. Otherwise infer from the input: a file
that already contains a threat table or STRIDE analysis implies REVIEW; an architecture or
design doc implies AUTHOR. If still ambiguous, use AskUserQuestion to ask author-new vs
review-existing.

## Step 2: Locate Inputs

If the user passed a path, use it. Otherwise scan:

**For REVIEW** — find an existing model:
`**/THREAT-MODEL.md`, `**/threat-model.md`, `**/THREATMODEL.md`, `**/security/*.md`

**For AUTHOR** — find architecture inputs:
`**/ARCHITECTURE.md`, `**/design.md`, `**/DESIGN.md`, `**/plan.md`, `**/PLAN.md`, `**/README.md`

If no design doc exists, scan source for entry points and trust boundaries:
```bash
grep -rnE "route|router|@app\.(get|post|put|delete)|http\.Handle|addEventListener|listen\(|app\.(get|post|use)|@RequestMapping|def .*request" --include=*.py --include=*.js --include=*.ts --include=*.go --include=*.java --include=*.rb .
```
Also locate data stores (DB clients, ORM models, connection strings) and external calls
(outbound HTTP, queues, third-party SDKs).

If multiple candidates exist, use AskUserQuestion.

Read the full input — at minimum all section headers plus the first 80 lines of each section,
or the located entry-point/handler files.

## Step 3: Load the STRIDE Catalog and Coverage Checklist

Read both reference files from this skill's directory
(`~/.claude/skills/threat-model/`):

- `STRIDE-CATALOG.md` — the six categories: definition, the security property each violates,
  example threats, and the probing questions to ask of every data-flow element.
- `CHECKLIST-COVERAGE.md` — what a complete model must enumerate and walk.

For AUTHOR mode also read:
- `TEMPLATE.md` — the threat model document skeleton.
- `references/MITIGATION-LIBRARY.md` — common mitigations keyed by STRIDE category.
- `references/EXAMPLES.md` — a worked mini example.

## Step 4: Spawn the Threat Modeler Agent

Spawn the specialized threat-modeler subagent. Read `subagents/threat-modeler.md` for the
full agent prompt. Pass it:
1. The mode (AUTHOR or REVIEW)
2. The input path(s) and any located entry-point/handler files
3. The contents of `STRIDE-CATALOG.md` and `CHECKLIST-COVERAGE.md`
4. For AUTHOR: `TEMPLATE.md`, `references/MITIGATION-LIBRARY.md`, `references/EXAMPLES.md`

In AUTHOR mode the agent enumerates assets, trust boundaries, external entities, data stores,
data flows, and entry points, then walks each element through all six STRIDE categories.

In REVIEW mode the agent rates each coverage-checklist item **PRESENT / PARTIAL / MISSING**
with a one-line note for anything PARTIAL or MISSING.

## Step 5a: Author — Emit the Document

Use `TEMPLATE.md` to structure the output. The document must include:
- System overview
- Assets / crown jewels
- Trust boundary diagram (text or mermaid)
- Data flow inventory
- Threat table: ID, element, STRIDE category, threat, likelihood, impact, mitigation, status
- Mitigations
- Residual risks
- Assumptions / out-of-scope

Draw mitigations from `references/MITIGATION-LIBRARY.md` keyed by category. Write the document
to `THREAT-MODEL.md` next to the input (or a path the user specifies).

## Step 5b: Review — Emit the Coverage Report

Produce a report with:
- Summary scorecard (counts of PRESENT / PARTIAL / MISSING)
- Critical gaps in priority order (un-walked elements, threats with no mitigation)
- Partial items needing strengthening
- 3–5 genuine strengths
- Top 5 recommended next steps

## Step 6: Offer to Fix

After delivering, ask: "Would you like me to draft the missing threats and mitigations?"

If yes, re-spawn the threat-modeler subagent in AUTHOR mode scoped to only the MISSING and
PARTIAL elements, and insert the new threat-table rows and mitigations into the document.
Prioritize un-walked elements and un-mitigated high-impact threats first.
