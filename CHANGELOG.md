# Changelog

All notable changes to skills in this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Fixture-coverage ratchet** (2026-09-16) — `scripts/test-script-fixtures.sh`
  no longer lets a new `score-*`/`scan-*`-class script ship unpinned. Replaying
  fixtures only failed when a pin existed and drifted; a brand-new script with
  no fixture shipped silently — the pre-2026-09-15 failure mode re-opened for
  future scripts. The suite now enumerates every skill script in the fixture
  families (`score-*`, `scan-*`, `find-*`, `collect-*`, `*_hygiene.sh`) and
  fails unless each is replayed there or listed in `FIXTURE_EXEMPT` with a
  reason (`plan-review/scripts/score-plan.sh`, deprecated and unreferenced, is
  the only entry), with a count floor so the enumeration itself cannot go
  blind. The ratchet's first run caught the one live gap:
  `plan-review/scripts/scan-headers.sh` was wired into the skill but never
  pinned — now replayed against the same fixture document as `find-forks.sh`
  (header census, PRESENT/MISSING verdicts, file stats, the
  `grep -c || echo 0` doubled-zero quirk pinned as known behavior, usage
  errors). 125 → 160 pinned assertions.
- **SELF-TEST script fixtures now run unattended** (2026-09-15) — the
  per-skill `SELF-TEST.md` heredoc fixtures (exact counts, MISSING lists,
  per-style inventories, exit codes) are replayed mechanically by
  `scripts/test-script-fixtures.sh`, wired into the pre-commit hook and the
  `skills-validate` Argo WorkflowTemplate so the pins gate every commit and
  every push instead of living only in a manual runbook. Covers all nine
  script-bearing skills with 125 pinned assertions; the LLM-in-the-loop
  functional sections stay manual.
  The suite passes identically against the pre-`lib/common.sh` scripts and the
  extracted ones — it is the before/after net for the extraction. The
  repo-hygiene fixture (and its `SELF-TEST.md` runbook) no longer seeds a
  `.github/workflows/` directory, which is prohibited workspace-wide even as a
  throwaway; `dead-ci-workflows` stays the one detector the fixture leaves
  unexercised.

### Changed
- **Stale inlines are drift** (2026-09-16) — the inline excusal in
  `check-installed.sh` was marker-based: any installed copy carrying the
  "Inlined from lib/common.sh" marker passed the repo diff, so a `lib/common.sh`
  fix in the repo left every already-installed copy silently running the old
  helpers forever. The checker now re-derives the expected inline from the
  current repo script plus the current lib — the same derivation install.sh
  writes, as one implementation in `lib/inline.sh` sourced by both — and
  excuses only a byte-identical match. Anything else (older lib at install
  time, hand-edit) is reported as `Stale inline` per skill with the re-install
  remedy, exit 1. A lib change is now a re-install trigger for the four skills
  whose scripts inline it (`plan-author`, `plan-review`, `readme-review`,
  `spec-review`); README says so. Pinned in `scripts/test-root-scripts.sh`
  (fresh install clean, hand-edit stale, lib-fix-after-install stale,
  re-install lands the new helpers).
- **install.sh now performs usage-statusline's out-of-tree install** (2026-09-15) —
  in addition to the skill directory it deploys `~/.claude/usage-statusline.sh`
  and merges the `statusLine` block into `~/.claude/settings.json` alongside
  existing keys: idempotent on re-run, never displacing a `statusLine` running
  something else, leaving invalid JSON byte-identical with exit 1.
  `check-installed.sh`'s out-of-tree diff now also fires on any sweep where a
  deployed copy exists, not only when the skills-dir install lets the sweep
  intersect the skill — a machine with the deployment but no skills-dir copy
  previously reported "No drift detected" while the deployed copy (where
  ADR-1's hardcoded `/home/coding` path was found live) had drifted. All of it
  pinned in `scripts/test-root-scripts.sh`.
- **Drift fix is now `./install.sh <skill>`, not a bare `cp -r`** (2026-09-15) —
  repo scripts source the shared `../../lib/common.sh`, a path that resolves
  outside a per-skill copy, so the old documented remedy installed scripts that
  fail at source time. `install.sh` inlines the lib (and redeploys
  usage-statusline's out-of-tree copy); the README drift section and
  `check-installed.sh`'s remedy output now say so, and the checker flags the
  broken-lib state a bare copy produces (it is byte-identical to the repo, so
  the diff alone sees nothing). Pinned in `scripts/test-root-scripts.sh`.

### Fixed
- **CI fixtures step runs GNU userland** (2026-09-16) — the `skills-validate`
  WorkflowTemplate's `script-fixtures` step moved from `alpine/git` to
  `debian:bookworm-slim`: busybox broke 5 of the suite's 160 pins on its
  first live run (`wc -w` drops multibyte words — 131 vs the pinned 136 on
  the plan-review fixture — and busybox `grep` has no `--include`, which
  silently emptied `scan-tests.sh`'s framework list, its stderr discarded).
  The pins were authored against GNU behavior and stay byte-identical.
  Hardening the skill scripts themselves for busybox/macOS (`wc -w` × 2,
  `grep -r --include` × 1) is a deliberate follow-up, not folded in here.
- **CI fixtures step can clone over TLS** (2026-09-16) — the first
  push-triggered run on the Debian image (`skills-validate-p8c9v`) failed
  before any fixture executed: bookworm's `git` package lists
  `ca-certificates` only as a Recommends, and the step installs with
  `--no-install-recommends`, so the container had no TLS trust store and
  `git clone` died on certificate verification with exit 128 — ~21 s in,
  after apt had succeeded. `validate-skills` cloned fine from the same
  cluster because `alpine/git` carries ca-certificates as a hard
  dependency, which is what made the failure look like a fixtures problem
  rather than a network one. The WorkflowTemplate now installs
  `ca-certificates` explicitly (declarative-config `79545295`); the suite
  itself needed no change.

### Added
- Version field to all skill frontmatter (1.0.0 initial version for all 16 skills)
- Root-script contract suite `scripts/test-root-scripts.sh` (2026-09-15) — fixture-based
  shell test (temp HOME with a fake `~/.claude/skills/`; the real home is never touched)
  pinning the documented behavior of `check-installed.sh` (exit codes 0 = no drift,
  1 = drift, 2 = missing skills directory) and `install.sh` (`--list`, selective install
  that leaves sibling skills untouched, `--all`). Runs in the pre-commit hook alongside
  `validate-skills.sh` (re-run `scripts/install-hooks.sh` to pick it up on an existing
  checkout).

### Changed
- **gap-review → plan-gap-review 2.0.0** (2026-08-21) — renamed. Major bump because the
  rename breaks the invocation: `/gap-review` no longer resolves. The skill's behaviour is
  unchanged. The new name states what the skill is actually for — reviewing a plan, spec, or
  design document — rather than reading as a generic "find gaps in anything", and it groups
  with the other plan-lifecycle skills (`plan-author`, `plan-review`, `plan-idea-gen`).
  - Callers must update `/gap-review` to `/plan-gap-review`.
- **plan-review 2.0.0** (2026-08-20) — rewritten around a *decision ledger* instead of an
  83-item header checklist. Motivation: plans were passing review at "88% present" while
  their implementation language, cache-staleness rule, or registry target was still
  undecided; those decisions then surfaced as ADRs appended after the plan was "done", or as
  production incidents. The review now asks what the implementer will be forced to decide
  that the plan has not — and proposes each decision.
  - New: `references/DECISION-LEDGER.md` (fork catalog, with the incident each open fork
    becomes), `references/STRUCTURAL-SWEEP.md` (the eleven categories plus port /
    improvement / integration / migration / spike, consolidated, N/A-aware),
    `references/EXEMPLARS.md` (locked-decision forms and anti-patterns), `runbooks/LOCK.md`
    (`--lock` writes decisions into their home sections), `runbooks/FAST-PATH.md`,
    `scripts/find-forks.sh` (line-anchored locator: DEFER / HEDGE / SHADOW / AMENDED /
    UNQUANTIFIED).
  - Verdict is NOT READY / READY AFTER DECISIONS (n) / READY, driven by seven safety caps.
    No percentages.
  - Runs inline; `Agent` removed from `allowed-tools`. The memo is written to
    `docs/notes/plan-review-<date>.md` (or next to the plan) before it is summarised.
  - Removed: `CHECKLIST-01..11.md`, `TYPE-*.md`, `subagents/`, `runbooks/QUICK-TRIAGE.md`,
    `runbooks/STALE-PLAN.md` (folded into the reality lens), `references/PIVOT-CAUSES.md`
    and `references/HIGH-QUALITY-EXAMPLES.md` (folded into the ledger and exemplars).
  - Deprecated: `scripts/score-plan.sh` is no longer referenced — its READY / NOT READY
    output rewarded length. Retained until bead `jedscura-abeab37c` (shared-lib extraction)
    lands, then removed.

## [1.0.0] - 2026-05-16 to 2026-07-25

### Added
- **plan-review** - 2026-05-16
  - Initial release of comprehensive pre-flight review skill for software plans
  - Checks 80+ structural patterns across scope, acceptance criteria, architecture, safety, phasing, testing, security, performance, operations, API design, and risk

- **adr** - 2026-06-26
  - Architecture Decision Record authoring and review skill
  - Supports steel-manned alternatives and honest consequence documentation

- **api-design-review** - 2026-06-26
  - REST, gRPC, GraphQL, and CLI API surface review for design quality and evolvability
  - Checks resource modeling, semantics, versioning, payloads, and security

- **diff-review** - 2026-06-26
  - Language-agnostic structural code diff review with adversarial verification
  - Suppresses false positives through refutation pass

- **migration-runbook** - 2026-06-26
  - Reversible cutover/migration runbook authoring
  - Every step paired with verification gate and rollback

- **plan-author** - 2026-06-26
  - Inverse of plan-review: generates complete plan.md from brief
  - Produces all eleven structural categories plan-review checks for

- **postmortem** - 2026-06-26
  - Blameless incident postmortem authoring and review
  - Timeline, root-cause analysis, and owned action items

- **readme-review** - 2026-06-26
  - README quality review tuned to project type (library/CLI/service/app)
  - Zero-to-running walkthrough verification

- **release-readiness** - 2026-06-26
  - Go/no-go gate for releases with evidence-backed verdict
  - Checks quality, versioning, operations, and communications

- **spec-review** - 2026-06-26
  - Pre-plan gate for product/requirements specs
  - Reviews for ambiguity, untestable requirements, and missing NFRs

- **test-plan-review** - 2026-06-26
  - Suite-level test directory or test plan review
  - Identifies coverage gaps and tests that will lie

- **threat-model** - 2026-06-26
  - STRIDE-based threat model authoring and review
  - Enumerates assets, trust boundaries, data flows, and entry points

- **usage-statusline** - 2026-07-19
  - Live Claude Code statusline showing session and weekly usage
  - Rolling commit counter and time-to-exhaustion projection

- **gap-review** - 2026-07-21
  - Iterative gap-and-contradiction review for plans, specs, and design documents
  - Brainstorms 20 solutions per gap, applies best, re-analyzes until clean

- **plan-idea-gen** - 2026-07-21
  - Wide-then-narrow ideation anchored to plan.md
  - Generates pool of ideas via forced-diversity lenses, filters to top K through clustering and adversarial kill pass

- **repo-hygiene** - 2026-07-11
  - Repository hygiene audit with optional fix mode
  - Detects committed build artifacts, dead GitHub Actions, README drift, dirty trees, and suspicious tracked files
- **repo-hygiene** - 2026-07-25
  - Added root-ad-hoc-files check (bf-3o9 hygiene guard)

[Unreleased]: https://github.com/jedarden/jeds-curated-skills/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jedarden/jeds-curated-skills/releases/tag/v1.0.0
