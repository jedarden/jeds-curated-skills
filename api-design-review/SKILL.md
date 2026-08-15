---
name: api-design-review
version: 1.0.0
description: >-
  Reviews an API surface — REST/OpenAPI, gRPC/proto, GraphQL schema, or CLI — for design
  quality and evolvability before it is locked. Rates resource modeling, method semantics,
  versioning, payloads, and security against an opinionated checklist.
  Use when an API contract is being designed or about to ship and breaking it later is costly.
argument-hint: "[path/to/openapi.yaml | *.proto | schema.graphql | routes file]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# API Design Review Skill

Review an API surface for design quality and evolvability before it is locked. Interface
decisions are the most expensive thing to change after launch — this skill catches the
mistakes that force a v2, a breaking migration, or a chatty client rewrite.

It works for any API style: REST/OpenAPI, gRPC/protobuf, GraphQL, or a command-line surface.

## Step 1: Locate the API Definition

If the user provided a path as an argument, use that. Otherwise glob for, in order:
`**/openapi*.{yaml,yml,json}`, `**/swagger*.{yaml,yml,json}`, `**/*.proto`,
`**/schema.graphql`, `**/*.graphql`, `**/schema.gql`, and route/handler files
(`**/routes*.{ts,js,py,go,rb}`, `**/*router*.{ts,js,py,go}`, `**/urls.py`).

If a design doc describes the API in prose (`**/api-design*.md`, `**/API.md`), accept that too.

If multiple unrelated candidates exist, use AskUserQuestion to pick the surface under review.

Read the full definition — every path/method, every message/service, or every type/field.

## Step 2: Detect API Style

Run the inventory scan to classify the surface and get a quick count:
```bash
~/.claude/skills/api-design-review/scripts/scan-api.sh <path-or-dir>
```

Classify as one of: **REST**, **gRPC**, **GraphQL**, or **CLI**. The checklists apply to all
styles; the script's inventory tells the reviewer where to focus (e.g. proto field tags for
gRPC evolution, cursor pagination for REST/GraphQL collections).

## Step 3: Load Checklists

Read ALL of the following checklist files from this skill's directory
(`~/.claude/skills/api-design-review/`). They contain the full review criteria:

- `CHECKLIST-01-RESOURCES.md` — Resource modeling & naming
- `CHECKLIST-02-SEMANTICS.md` — Method/verb semantics & status codes
- `CHECKLIST-03-EVOLUTION.md` — Versioning & backward compatibility
- `CHECKLIST-04-PAYLOADS.md` — Errors, pagination, filtering & formats
- `CHECKLIST-05-SECURITY-LIMITS.md` — Authn/authz, rate limits & input safety

Also read `references/ANTIPATTERNS.md` — the catalog of failure modes the reviewer matches
findings against.

## Step 4: Spawn the Review Agent

Spawn the specialized api-reviewer subagent. Read `subagents/api-reviewer.md` for the full
agent prompt. Pass it:
1. The API definition path(s)
2. The detected API style (REST / gRPC / GraphQL / CLI)
3. All checklist file contents
4. The `references/ANTIPATTERNS.md` content (for naming the specific anti-pattern hit)

The agent rates each checklist item: **PRESENT** / **PARTIAL** / **MISSING** with a one-line
note (and the offending path/field/method) for anything PARTIAL or MISSING.

## Step 5: Generate Report

Use `REPORT-TEMPLATE.md` to structure the output. The report must include:
- Summary scorecard (counts of PRESENT / PARTIAL / MISSING per category)
- Critical issues in priority order (breaking-change risks first)
- Items needing strengthening
- 3–5 genuine strengths
- Top 5 recommended next steps

## Step 6: Offer to Fix

After delivering the report, ask: "Would you like me to draft fixes for the MISSING items?"

If yes, draft concrete changes against the actual definition — e.g. add an error envelope
schema, a cursor pagination parameter set, a `Retry-After` header on 429, a versioning
header, or renamed resource paths. Edit the spec/schema in place where safe; otherwise emit
a diff-style proposal. Prioritize Category 03 (Evolution) and Category 02 (Semantics) first —
those are the changes that are impossible to make after clients integrate.
