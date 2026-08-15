# jeds-curated-skills

A collection of Claude Code skills for agent-driven software development workflows.

## Installation

Use the included installer to select which skills to install:

```bash
# Clone the repository
git clone https://github.com/jedarden/jeds-curated-skills ~/jeds-curated-skills

# List available skills
cd ~/jeds-curated-skills
./install.sh --list

# Install specific skills (doesn't touch other skills already in ~/.claude/skills/)
./install.sh plan-review repo-hygiene

# Install everything
./install.sh --all
```

**Or** clone directly to your Claude Code skills directory (overwrites existing skills):

```bash
git clone https://github.com/jedarden/jeds-curated-skills ~/.claude/skills
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

#### `plan-idea-gen`

Wide-then-narrow ideation anchored to a specific plan.md.

Generates a large pool of ideas (default 100) across eight forced-diversity lenses, then
filters to the top K (default 10) through clustering, harsh triage, crossover hybrids,
pairwise ranking, and an adversarial kill pass — comparisons, never 1–10 scores. Finalists
arrive as decision-ready dossiers: pitch, complexity grade, concrete first step, and the
strongest objection that survived. Every idea — winners and losers alike — lands in a
per-repo ledger that future runs dedupe against, so the skill compounds per project.

**Usage:** `/plan-idea-gen [plan.md path or repo] [--pool N] [--keep K] [--constraint "..."] [--lens "..."]`

If the target plan is ambiguous it stops and asks rather than guessing. Adopted ideas can
flow into bead tracking and back into the plan's roadmap.

#### `gap-review`

Iterative gap-and-contradiction review of a plan, spec, or design document.

Fresh-eyes analysis agents hunt contradictions, dangling references, specification gaps,
and ambiguities that would block implementation. For each gap, a fix agent brainstorms 20
candidate solutions, ranks them against the document's goal, and applies the best; the
document is then re-analyzed — looping until a round comes back clean (max 5 rounds).

**Usage:** `/gap-review [path/to/document.md]`

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

#### `repo-hygiene`

Audit a repository for hygiene debt, with an optional guarded fix mode.

Detects committed build artifacts (`target/`, `node_modules/`, `__pycache__/`, ...),
tracked files over 5 MB, dead GitHub Actions workflows, README version-badge drift,
dirty trees and stash pileups, missing `.gitignore` coverage, and suspicious tracked
files (`.env`, keys — flagged for review, never read). The detection core is a plain
report-only bash script (`scripts/repo_hygiene.sh --json`) that any agent harness can
invoke directly — the skill is a thin wrapper that adds a fix mode applying one commit
per category, strictly limited to `.gitignore` entries, `git rm --cached`, dead
workflow removal, and badge fixes.

**Usage:** `/repo-hygiene [repo-path] [--fix]`

### Observe

#### `usage-statusline`

A live Claude Code statusline showing session and weekly usage against
elapsed-time pace, plus a rolling Claude-co-authored commit counter.

Renders each quota window as a percent, a ten-cell bar comparing usage-consumed
against time-elapsed, and an extrapolated time-to-exhaustion — so you see you're
overspending before you hit the wall instead of after. Unlike the other skills
here, it isn't invoked on demand; it installs a `statusLine` command that runs
on every prompt. See `usage-statusline/README.md` for the full legend.

**Usage:** ask Claude Code to "set up the usage statusline" (see `usage-statusline/SKILL.md`)

## Philosophy

These skills are designed for use in headless agent workflows — they should work without
human steering mid-execution. Each skill is self-contained: it locates its own inputs,
spawns its own subagents, and produces a complete output.
