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
| `scripts/test-root-scripts.sh` | Documented contracts of the root scripts, including the isolated factory-review timer install, re-install, dry-run, memory-failure, and uninstall fixtures |
| `scripts/test-script-fixtures.sh` | The per-skill `SELF-TEST.md` script fixtures: each score/scan script's heredoc fixture replayed mechanically against its pinned counts, MISSING lists, and exit codes — any mismatch fails the commit or the push |

The push path itself has an external heartbeat: `scripts/check-push-ci.sh`
runs every 30 minutes in `iad-ci` (the `push-ci-heartbeat` Argo CronWorkflow
in declarative-config, `k8s/iad-ci/argo-workflows/`), which clones this repo
and confirms the newest non-CI-authored `origin/main` push produced a
sensor-submitted `skills-validate` workflow in `iad-ci`. Only the script's
exit 1 (path dead — pushes landing unvalidated) fails the run and turns it
red; exit 2 (cannot judge) and exit 3 (inside the grace window) are recorded
and stay green. The check is still runnable by hand the same way; it waits
through a 15-minute delivery grace window by default — use `--grace-minutes 0`
when the push is already old enough to judge. A passing check covers the
Forgejo route, JetStream delivery, sensor trigger, and Workflow submission
together.

To run any of them by hand:

```bash
./scripts/test-root-scripts.sh    # includes factory-review timer fixtures
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

For automated, scheduled review of multiple workspaces, install the systemd `--user` timers:

```bash
cd ~/jeds-curated-skills
./scripts/install-review-timers.sh
```

The installer manages four weekly workspace checks plus one machine-local drift check, all
staggered across the week. Each row installs the named `.timer`, its paired `.service`, and a
runner script under `~/.config/factory-review/`:

| Timer | Service | Schedule | Action |
|-------|---------|----------|--------|
| `factory-review-plan-vs-built.timer` | `factory-review-plan-vs-built.service` | Mon 02:00 | `plan-vs-built` |
| `factory-review-find-stubs.timer` | `factory-review-find-stubs.service` | Tue 02:00 | `find-stubs` |
| `factory-review-repo-hygiene.timer` | `factory-review-repo-hygiene.service` | Wed 02:00 | `repo-hygiene` |
| `factory-review-memory-tool.timer` | `factory-review-memory-tool.service` | Thu 02:00 | `memory-tool check` |
| `factory-review-installed-drift.timer` | `factory-review-installed-drift.service` | Fri 02:00 | installed-skill drift (`scripts/check-installed.sh`) |

### What gets installed

The command must be run from the checkout whose skills and drift state should be reviewed. It
requires a user systemd manager and these commands available to the installer or generated
runners: `bash`, `systemctl`, `journalctl`, `claude`, `memory-tool`, and the bead CLI declared
by each workspace (`bead` for bead-rs or `bf` for legacy bead-forge). The installer resolves
`bash` with `command -v` and embeds that path in the service units, which also avoids assuming
that `/bin/bash` exists. Each runner prepends `$HOME/.local/bin:$HOME/.cargo/bin` to `PATH` so
user-installed `claude`, `memory-tool`, and bead CLIs are found under systemd.

The generated files are:

```text
~/.config/factory-review/workspaces.txt
~/.config/factory-review/factory-review-*.sh
~/.config/systemd/user/factory-review-*.service
~/.config/systemd/user/factory-review-*.timer
```

Services are `Type=oneshot` units with a 30-minute timeout and `Nice=10`; output goes to the
user journal. Timers use `Persistent=true`, so a missed scheduled run is considered when the
user manager returns. Installation runs `systemctl --user daemon-reload` and
`systemctl --user enable --now` for all five timers when the user manager is available. If it
is not available, the generated files remain installed and the script prints the command to
activate them later.

The installer creates `~/.config/factory-review/workspaces.txt` with comments if it does not
exist. Put one workspace path on each line; for example:

```text
# Absolute paths are accepted.
/home/coding/project-a

# ~ and paths without a leading slash are relative to $HOME.
~/project-b
projects/project-c
```

Blank lines and lines whose first non-whitespace character is `#` are ignored. `~` expands to
`$HOME`, and other relative paths are also resolved relative to `$HOME`. Missing directories are
skipped. The first three workspace timers invoke `claude --print` for their skill; the
`repo-hygiene` invocation additionally passes `--file-beads`. Each review runs from the target
workspace and uses that workspace's declared bead backend for findings (`bead` for `bead-rs`,
`bf` for legacy `bf`/bead-forge); the review runners do not write `.beads/` directly. A failure
in one workspace is reported and makes that service fail, but the remaining configured
workspaces are still processed.

The `memory-tool` timer is different: it is a host check, runs exactly once, and ignores
`workspaces.txt`. It chooses its filing workspace from `FACTORY_REVIEW_HOME_WORKSPACE` when
set, otherwise `$HOME/jeds-curated-skills`; when that default is not a workspace checkout, it
falls back to the checkout from which the installer was run if that checkout has `.needle.yaml`
and `.beads`.

On failure, the generated memory runner reads `bead_cli.backend` from that workspace's
`.needle.yaml`:

- `bead-rs` (or `bead`) invokes `bead create --issue-type task` with the stable
  `factory-review:memory-tool-check` unique reference, so repeated failures are idempotent.
- `bf` (or `bead-forge`) invokes the legacy `bf create --type task` form and checks open items
  first to avoid filing a duplicate.

Both paths use the `factory-review` and `memory-tool` labels. The runner suppresses
`memory-tool check` diagnostics, including credential-bearing output, and files only the safe
failure status. A successful check prints exactly `memory-tool check passed; nothing to file.`
If the check fails but the selected workspace has no bead store/backend, has an unsupported
backend, or lacks the selected CLI on `PATH`, it prints an explicit `nothing to file` or
`unable to file bead` outcome and returns the original check's failure code. A filing failure
also preserves that check code; it never turns a failed check into a false success.

The installed-drift timer is machine-local rather than per-workspace: it runs
`scripts/check-installed.sh` once a week from this checkout, including the full skill sweep and
the `usage-statusline` deployed copy. It ignores `workspaces.txt`. Exit 1 means drift was
found, so it files one deduplicated bead in this checkout and leaves the service failed for
inspection. Exit 2 means a usage/environment problem such as a missing `~/.claude/skills/`
directory; it files no bead because that is not drift.

An empty workspace list has an intentional, explicit outcome: workspace runners print
`No configured workspaces; nothing to file.` and do not invent a finding. This does not disable
the independent `memory-tool` or installed-drift checks.

### Operate and inspect

Re-running the installer from the same checkout is idempotent: it regenerates the same
installer-owned service, timer, and runner files, reloads the user manager, and re-enables the
timers without creating duplicate units.

```bash
# Re-install or repair the generated units
./scripts/install-review-timers.sh

# Reload systemd
systemctl --user daemon-reload

# Enable all timers
systemctl --user enable --now factory-review-*.timer

# List next/last runs for every factory-review timer
systemctl --user list-timers --all | grep factory-review

# Inspect a timer and its last service result
systemctl --user status factory-review-memory-tool.timer
systemctl --user status factory-review-memory-tool.service

# Run a service immediately, without waiting for its calendar time
systemctl --user start factory-review-memory-tool.service
journalctl --user -u factory-review-memory-tool.service --no-pager

# The same manual form works for a workspace review
systemctl --user start factory-review-plan-vs-built.service
```

`systemctl --user list-timers --all` shows the staggered next-run time and the last result;
`systemctl --user status` and `journalctl` show the unit's detailed outcome. In particular,
the drift timer intentionally remains failed after exit 1 so its finding is visible in those
inspections.

Preview generation without creating the config directory, unit files, runner scripts, or
systemd state:

```bash
./scripts/install-review-timers.sh --dry-run
```

The installer accepts no option for a normal install, `--dry-run` to preview, `--uninstall` to
remove its generated units, and `--help` (or `-h`) to print usage. An unknown option exits with
an error and the usage text.

Remove only the timers, services, and runner scripts owned by this installer with:

```bash
./scripts/install-review-timers.sh --uninstall
```

The workspace list is not removed. Uninstall stops and disables active/enabled timers before
removing their files, then reloads the user manager; unrelated user units and scripts are
left alone.

### Fixture verification

The complete timer lifecycle is covered by `scripts/test-root-scripts.sh` (run it with
`bash scripts/test-root-scripts.sh`, expecting exit 0). It uses a temporary `HOME`, fake
`systemctl`, fake `claude`, fake `memory-tool`, and fake `bead`/`bf` CLIs, so it never touches the
real user manager, workspace list, or bead store. The fixture checks every generated service,
timer, and runner (the four workspace review timers plus the installed-drift timer), including
oneshot/timeout/Nice/PATH/journal properties, staggered calendars, persistent activation, and
manual service execution. It also checks that repeated install is byte-identical, `--dry-run`
prints the generated commands without filesystem side effects, a successful review is observable,
an empty workspace list reports `No configured workspaces; nothing to file.`, a passing memory
check files no bead, and failing bead-rs/legacy checks preserve their exit code while filing one
deduplicated bead without exposing diagnostics. Finally, `--uninstall` removes every
installer-owned artifact while preserving the workspace list and foreign files. Keep these
expectations in sync with this operator documentation when the timer contract changes.

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
