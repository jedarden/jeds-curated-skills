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

## Checking for drift

Skills are installed by copying into `~/.claude/skills/` (normally via `./install.sh`) with no automatic update or drift-detection mechanism. If you edit skills locally or update the repo, installed copies can silently diverge from the canonical source.

To check for drift between installed skills and the repo:

```bash
cd ~/jeds-curated-skills
./scripts/check-installed.sh
```

This checks all skills present in both the repo and `~/.claude/skills/`, reporting any files that differ or are missing on either side.

To check specific skills only:

```bash
./scripts/check-installed.sh plan-review repo-hygiene usage-statusline
```

**Exit codes:**
- `0` — No drift found
- `1` — Drift detected
- `2` — Usage error or `~/.claude/skills/` directory not found

To fix drift, re-install the affected skill with the installer:

```bash
./install.sh plan-review
```

Do not fix drift with a bare `cp -r <skill>/ ~/.claude/skills/`. In this repo,
five scripts across four skills source the shared `../../lib/common.sh` — a path
that resolves to a `lib/` directory *beside the skill's parent*, present only in
a full clone of the repo and never in a per-skill install. A plain copy
byte-identical to the repo therefore installs scripts that fail at source time.
`./install.sh` inlines `lib/common.sh` into those scripts at install time so
each installed skill is self-contained, and for `usage-statusline` it also
redeploys the out-of-tree `~/.claude/usage-statusline.sh` and re-wires
`settings.json`. `check-installed.sh` flags the broken-lib state too, since the
diff alone sees a byte-identical copy as clean.

**Stale inlines are drift.** An installed script differing from its repo source
is expected only while it is byte-identical to what `./install.sh` would inline
*today*: the checker re-derives the expected inline from the current repo copy
of the script plus the current `lib/common.sh` (the same derivation the
installer writes, shared via `lib/inline.sh`) and compares. The inlining marker
alone proves nothing. So when `lib/common.sh` changes in the repo, every
already-installed copy of the four skills the installer inlines for —
`plan-author`, `plan-review`, `readme-review`, and `spec-review` — still runs
the helpers it was installed with, and the next check reports them as
`Stale inline` drift — the fix is the usual re-install, which re-inlines from
the current lib:

```bash
./install.sh plan-author plan-review readme-review spec-review
```

`usage-statusline`'s deployed copy is checked directly: `check-installed.sh`
diffs `~/.claude/usage-statusline.sh` against the repo whenever the skill is
named, and on any sweep where a deployed copy exists — including a machine with
no `~/.claude/skills/usage-statusline/` for the sweep to intersect. A drift
there is fixed the same way: `./install.sh usage-statusline` redeploys the
script and re-wires `settings.json` (without displacing an existing
`statusLine`).

The drift checker detects the same issue that motivated this repo's own ADR-1: the installed `~/.claude/usage-statusline.sh` once hardcoded `/home/coding` while the repo's version generalized to `$HOME` — silent drift that went unnoticed until manual inspection.

## Testing

Three suites run before each commit (via the pre-commit hook installed by `scripts/install-hooks.sh`) and on every push to `main` (via the `skills-validate` Argo WorkflowTemplate, which triggers on push through the Forgejo webhook sensor):

| Suite | Covers |
|-------|--------|
| `scripts/validate-skills.sh` | Static structure per ADR-1: frontmatter schema, reference integrity, `bash -n`, executable bits, ShellCheck baseline ratchet |
| `scripts/test-root-scripts.sh` | Documented contracts of the root scripts: `check-installed.sh` exit codes, `install.sh` flag behavior and out-of-tree statusline install, `install-hooks.sh` pre-commit hook install |
| `scripts/test-script-fixtures.sh` | The per-skill `SELF-TEST.md` script fixtures: each score/scan script's heredoc fixture replayed mechanically against its pinned counts, MISSING lists, and exit codes — any mismatch fails the commit or the push |

The push path itself has an external heartbeat: run `scripts/check-push-ci.sh`
to confirm the newest non-CI-authored `origin/main` push produced a
sensor-submitted `skills-validate` workflow in `iad-ci`. It waits through a
15-minute delivery grace window by default; use `--grace-minutes 0` when the
push is already old enough to judge. A passing check covers the Forgejo route,
JetStream delivery, sensor trigger, and Workflow submission together.

To run any of them by hand:

```bash
./scripts/test-script-fixtures.sh   # ~3s, no network, no LLM
```

The fixture suite is the regression net for the shared `lib/common.sh` extraction: every fixture passes identically against the pre- and post-extraction scripts, so a behavior change in the shared helpers (or in any scorer) surfaces as a named failing pin instead of a silent count drift. The LLM-in-the-loop functional sections of each `SELF-TEST.md` stay manual runbooks by design and are not covered here.

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

Pre-flight review of a software plan that hunts for the decisions an implementer will be
forced to make that the plan has not made — and proposes each one — so the plan itself is the
decision record and no ADRs are needed mid-build.

Five lenses, run inline in one context: a **decision ledger** (every fork classified
LOCKED / ASSERTED / RECOMMENDED / SPIKED / DEFERRED / UNNOTICED / SHADOW, each open one
resolved with *Decision / Because / Rejected / Enforced by / Revisit if*), an **implementer
dry run** that narrates the first files a worker would create and the first question they
cannot answer, a **reality check** of the plan's claims against the actual repo and cluster,
seven **safety caps** (any one ⇒ NOT READY — there are no percentages), and a compact,
applicability-aware **structural sweep** as the safety net. The output is a memo written next
to the plan: verdict first, then "Decide these now".

**Usage:** `/plan-review [path/to/plan.md]` · `--fast` for a five-minute caps-and-forks check ·
`--lock DN-1,DN-3` (or `--lock all`) to write accepted decisions into the plan where an
implementer will read them.

Handles greenfield, port, improvement, integration, migration/cutover, and spike plans.
`scripts/find-forks.sh` is a line-anchored locator for deferred, hedged, shadowed, amended, and
unquantified decisions.

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

#### `plan-gap-review`

Iterative gap-and-contradiction review of a plan, spec, or design document.

Fresh-eyes analysis agents hunt contradictions, dangling references, specification gaps,
and ambiguities that would block implementation. For each gap, a fix agent brainstorms 20
candidate solutions, ranks them against the document's goal, and applies the best; the
document is then re-analyzed — looping until a round comes back clean (max 5 rounds).

**Usage:** `/plan-gap-review [path/to/document.md]`

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

**Usage:** ask Claude Code to "set up the usage statusline" (see `usage-statusline/SKILL.md`).
`./install.sh usage-statusline` performs the whole install — the skill
directory, the `~/.claude/usage-statusline.sh` deploy, and the `statusLine`
wiring in `~/.claude/settings.json` — idempotently, merging alongside existing
keys and never displacing a `statusLine` that runs something else.

## Factory Review Timers

For automated, scheduled review of multiple workspaces, install the weekly systemd --user timers:

```bash
cd ~/jeds-curated-skills
./scripts/install-review-timers.sh
```

This installs five staggered weekly timers:

| Timer | Schedule | Skill |
|-------|----------|-------|
| `factory-review-plan-vs-built.timer` | Mon 02:00 | plan-vs-built |
| `factory-review-find-stubs.timer` | Tue 02:00 | find-stubs |
| `factory-review-repo-hygiene.timer` | Wed 02:00 | repo-hygiene |
| `factory-review-memory-tool.timer` | Thu 02:00 | memory-tool check |
| `factory-review-installed-drift.timer` | Fri 02:00 | installed-skill drift (`scripts/check-installed.sh`) |

Each timer reads workspaces from `~/.config/factory-review/workspaces.txt` (one path per line) and runs the corresponding skill, filing beads in each workspace as needed. The `memory-tool` timer runs once per week (not per-workspace) and files a bead in the home workspace if the check fails.

The `installed-drift` timer is also machine-local rather than per-workspace: it runs `scripts/check-installed.sh` once a week from this repo (full sweep plus the `usage-statusline` out-of-tree deployed copy). On exit code 1 — drift detected — it files a bead in this repo's workspace, deduplicated while an open drift bead for that check already exists, and marks the systemd unit failed so the timer's last result is visible in `systemctl --user list-timers`. Without this timer the drift checker only runs when someone remembers to invoke it.

**After installation:**

```bash
# Reload systemd
systemctl --user daemon-reload

# Enable all timers
systemctl --user enable --now factory-review-*.timer

# Check status
systemctl --user list-timers | grep factory-review

# Test a service manually
systemctl --user start factory-review-memory-tool.service
journalctl --user -u factory-review-memory-tool.service
```

**Uninstall:**

```bash
./scripts/install-review-timers.sh --uninstall
```

**Dry-run (preview commands):**

```bash
./scripts/install-review-timers.sh --dry-run
```

## Philosophy

These skills are designed for use in headless agent workflows — they should work without
human steering mid-execution. Each skill is self-contained: it locates its own inputs,
spawns its own subagents, and produces a complete output.

### Lifecycle Flow

The skills cover the complete agent-driven development lifecycle from spec through
release. See [docs/notes/lifecycle.md](docs/notes/lifecycle.md) for the full SDLC map
showing when to invoke each skill, including branch points for spec vs. brief entry and
different plan types.

### Versioning

Each skill has a `version: X.Y.Z` field in its SKILL.md frontmatter and a corresponding
entry in the root CHANGELOG.md. When a skill's SKILL.md, checklists, or scripts change
materially (typo fixes excluded), bump its version and add a CHANGELOG entry.

This convention supports drift detection: users with local skill copies can compare their
version against the upstream CHANGELOG to see whether they're missing changes. The
drift-checker bead (jcs-3) will eventually report version mismatches automatically.

---

Part of [jedarden.com](https://jedarden.com)

*This GitHub repo is a read-only mirror of git.ardenone.com/jedarden/jeds-curated-skills — issues and PRs are welcome here either way.*
