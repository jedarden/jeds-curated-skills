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

Each skill is a self-contained, checklist-driven artifact derived from the structural
patterns of high-quality work. They cover the agent-driven development lifecycle from
spec through release.

### Plan & design

#### `plan-author`

The inverse of `plan-review`: turns a short brief or idea into a complete `plan.md`.

Generates the same eleven structural categories `plan-review` checks for — scope lock,
acceptance scenarios, architecture, pre-flight safety, phasing, testing, security, performance,
operations, API design, and risk — so the draft is built to pass review on the first pass. Makes
concrete decisions and parks genuine unknowns as numbered Open Questions rather than vague TBDs.

**Usage:** `/plan-author [brief text | path/to/brief.md] [--out path/to/plan.md]`

Supports greenfield, port, improvement, and integration plan types. For port and improvement
plans it first scans the existing codebase so the plan is grounded in reality. Self-scores the
draft against a completeness bar and backfills any thin sections before writing the file.

#### `plan-review`

Pre-flight review of a software plan document before implementation begins.

Checks 80+ structural patterns across scope, acceptance criteria, architecture, safety,
phasing, testing, security, performance, operations, API design, and risk — derived from
analysis of high-quality planning documents. Catches the gaps that cause mid-implementation
pivots before any worker touches the code.

**Usage:** `/plan-review [path/to/plan.md]`

Supports greenfield, port, improvement, and integration plan types. Includes a quick triage
mode, stale-plan runbook, and multi-plan comparison runbook. After the report, offers to
draft missing sections.

#### `spec-review`

A pre-plan gate: reviews a PRD or requirements doc for ambiguity, untestable requirements,
and missing non-functional considerations before a plan is written.

Quotes each ambiguous phrase verbatim and proposes a precise rewrite, then checks clarity,
testability, completeness (NFRs, error/edge states), and constraints. Feeds clean requirements
into `plan-author`.

**Usage:** `/spec-review [path/to/spec.md]`

#### `adr`

Author or review Architecture Decision Records.

In author mode it computes the next sequence number and drafts a complete ADR with steel-manned
alternatives and honest negative consequences. In review mode it rates an existing ADR and hunts
"the two lies" — strawman alternatives and all-positive consequences.

**Usage:** `/adr [author <decision brief> | review <path>]`

#### `threat-model`

Produce or review a STRIDE-based threat model.

Author mode enumerates assets, trust boundaries, data flows, and entry points, then walks STRIDE
per element and emits a threat table with mitigations. Review mode rates an existing model's
coverage and flags gaps.

**Usage:** `/threat-model [author | review] [path/to/architecture-or-model]`

### Implement & verify

#### `diff-review`

A generic, language-agnostic structural review of a code diff for correctness bugs and
design/cleanup issues.

Collects the diff itself, produces candidate findings tagged with `file:line`, then runs an
adversarial verification pass that tries to refute each finding and drops the ones it cannot
substantiate — biasing hard against false positives. Has a large-diff runbook for chunked,
parallel review.

**Usage:** `/diff-review [base-ref]`

#### `test-plan-review`

Suite-level review of a test directory or test plan for coverage gaps and tests that will lie
to you.

Names specific untested behaviors and the bug each missing test would catch, across coverage,
failure injection, non-functional concerns (concurrency, idempotency, cleanup), and test quality
(determinism, isolation, meaningful assertions).

**Usage:** `/test-plan-review [path/to/tests | path/to/test-plan.md]`

#### `api-design-review`

Review a REST, gRPC, GraphQL, or CLI API surface for design quality and evolvability before
it's locked.

Locates the API definition (OpenAPI, `.proto`, GraphQL schema, or routes), detects the style,
and reviews resource modeling, semantics, evolution/versioning, payloads, and security — naming
the specific anti-pattern behind each finding.

**Usage:** `/api-design-review [path/to/api-definition]`

#### `readme-review`

Review a project's README against a quality rubric tuned to its project type.

Infers whether the project is a library, CLI, service, or app, then runs an explicit
"zero-to-running" walkthrough and flags any install or usage step it cannot verify is complete.

**Usage:** `/readme-review [path/to/README.md]`

### Ship & operate

#### `release-readiness`

A go/no-go gate run before cutting a release, tag, or deploy.

Inspects the repo and changes since the last release, gathers evidence for each gate (quality,
versioning, operations, comms/docs), and emits a GO / CONDITIONAL / NO-GO verdict. A gate with
no evidence is marked MISSING, not passed. Includes a reduced-gate hotfix runbook.

**Usage:** `/release-readiness`

#### `migration-runbook`

Author a reversible cutover or migration runbook a human or agent can execute step by step.

Selects a migration pattern (expand-contract, dual-write + backfill, blue-green, canary,
strangler-fig), then writes a runbook where every step has an action, a verification gate, and a
rollback — with points-of-no-return flagged loudly.

**Usage:** `/migration-runbook [brief | --out path/to/runbook.md]`

#### `postmortem`

Author a blameless incident postmortem from an incident description and available artifacts.

Builds a timestamped timeline, drives root-cause analysis past a single cause into contributing
factors, and produces an action-items table where every item has an owner, a due date, and a
prevent/detect/mitigate classification — no "be more careful" items allowed.

**Usage:** `/postmortem [incident summary | path/to/notes]`

## Philosophy

These skills are designed for use in headless agent workflows — they should work without
human steering mid-execution. Each skill is self-contained: it locates its own inputs,
spawns its own subagents, and produces a complete output.
