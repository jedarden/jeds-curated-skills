# jeds-curated-skills — Plan

This file is the single decision log and architecture reference for this repo, per the
workspace's repo convention. It was created retroactively on 2026-07-20 — the repo shipped
14 skills over Jun 25–Jul 19 without a `docs/plan/plan.md`, so this file starts honest rather
than fabricating a plan-of-record after the fact. It grows forward from here as an ADR log.

## What this repo is

A curated collection of Claude Code **skills** — self-contained, checklist-driven Markdown +
bash bundles (`SKILL.md` + checklists + report templates + subagent prompts + optional
`scripts/*.sh`) that a Claude Code agent loads and follows in place of default behavior. There
is no server, no build, no container image, no k8s workload for the skill bundles themselves.

Distribution today is `git clone` (whole repo) or `cp -r <skill>/` (single skill) straight into
`~/.claude/skills/`, per README.md. One skill, `usage-statusline`, has a genuinely live
component: its `scripts/usage-statusline.sh` gets copied to `~/.claude/usage-statusline.sh` and
wired into `~/.claude/settings.json` as a `statusLine` command that runs on every prompt.

**Verified live on this machine (2026-07-20):** `usage-statusline` is installed and running —
`~/.claude/usage-statusline.sh` exists, is wired into `~/.claude/settings.json`, and
`~/.cache/claude-usage/usage.json` has a fresh (same-day) cache. Diffing the installed copy
against `usage-statusline/scripts/usage-statusline.sh` in this repo found one line of drift:
the installed copy hardcodes `/home/coding` in its commit-scan `find`, while the repo's current
version generalized that to `$HOME`. Nothing broke — but it's a live demonstration of the
problem ADR-1 addresses: a `cp`-once, no-registry distribution model with no way to detect that
an installed copy has drifted from the source of truth.

Of the 14 skills, only `plan-review` has any form of self-test (`SELF-TEST.md`) — and it's a
manual runbook, not something CI can run unattended (it names a sample plan path outside this
repo and drives the skill through an actual `/plan-review` invocation, i.e. it needs an LLM in
the loop). The other 13 skills have zero regression coverage: a bad edit to a checklist or a
`scripts/*.sh` heuristic would ship silently.

## Architecture notes

- Every skill follows the same shape: `SKILL.md` (frontmatter: `name`, `description`,
  `argument-hint`, `allowed-tools`) + numbered `CHECKLIST-NN-*.md` files + `REPORT-TEMPLATE.md`
  + `subagents/*.md` + optional `references/`, `runbooks/`, `scripts/*.sh`.
- 9 of the skills each carry their own `scripts/score-*.sh` or `scan-*.sh` — front-matter
  parsing, markdown header scanning, and percent/color formatting are reimplemented
  independently in each rather than shared.
- No CI is wired to this repo (consistent with the workspace-wide GH Actions ban); nothing
  currently lints the 11 shell scripts, validates `SKILL.md` frontmatter, or checks that files
  referenced from a `SKILL.md` (checklists, templates, subagent prompts) actually exist.
- Push mirror to GitHub (`jedarden/jeds-curated-skills`) is healthy — Forgejo push-mirror
  `sync_on_commit: true`, `last_error: ""`, last synced 2026-07-20T11:09:14Z.

## ADR-1: 2026-07-20 — Add a static structural-validation harness for skill bundles

- **Status:** Accepted
- **Date:** 2026-07-20
- **Deciders:** artifact-improvement audit pass (this session)

### Context

This repo has grown to 14 skills in under a month with no automated check that a skill is
internally consistent. The failure mode is specific and already latent: a `SKILL.md`
frontmatter typo (`allowed-tools` missing a tool the skill actually invokes), a checklist file
renamed without updating the reference in `SKILL.md`, or a shell script with a syntax error in
an untested branch — none of these would be caught before a user clones the repo and hits it
mid-task, headless, with no human watching. The one existing self-test (`plan-review/
SELF-TEST.md`) is a manual, LLM-in-the-loop runbook that references a path outside this repo
(`~/Research/dicklesworthstone-plans/...`) — it cannot run in CI and doesn't generalize to a
public clone.

Constraints:
- GitHub Actions are disabled workspace-wide; this repo has no Argo Workflows CI today and,
  unlike the app repos in the `Available WorkflowTemplates` table, isn't a container build —
  adding one requires either a new lightweight WorkflowTemplate or a local pre-commit hook.
- The repo is public — contributors (and future-us) need fast, cheap, dependency-light
  feedback. Anything requiring an LLM call is out of reach for a pre-commit hook and expensive
  to run on every push.
- 11 shell scripts across 9 skills currently have zero syntax/lint checking. `shellcheck` is
  not installed on this machine, so any check must degrade gracefully rather than hard-require
  it.
- Full functional testing (does `/plan-review` actually produce a good review?) requires an
  LLM in the loop and is a materially different, more expensive kind of test than structural
  validation. Conflating the two would make the harness slow and flaky.

### Decision

We will add a single static, dependency-tolerant validation script,
`scripts/validate-skills.sh`, at the repo root that runs across every skill directory and
checks, per skill:

1. **Frontmatter schema** — `SKILL.md` has a YAML frontmatter block; `name` matches the
   directory name; `description` and `allowed-tools` are present and non-empty.
2. **Reference integrity** — every relative Markdown link and every bare filename mentioned in
   `SKILL.md` that looks like a checklist/template/subagent/script path (`CHECKLIST-*.md`,
   `REPORT-TEMPLATE.md`, `subagents/*.md`, `scripts/*.sh`) resolves to a file that exists in
   that skill's directory.
3. **Shell syntax** — every `scripts/*.sh` passes `bash -n` (always available); if `shellcheck`
   is on `PATH`, also run it and report (not fail the build on) warnings, so the check works
   identically on a bare machine and a fully-provisioned one.
4. **Executable bit** — every `scripts/*.sh` referenced from a `SKILL.md` invocation snippet is
   `chmod +x`.

This is wired in two places: (a) as a local `git` pre-commit hook (installed via a
`scripts/install-hooks.sh` committed alongside it, since hooks themselves aren't versioned by
git) so a bad skill edit is caught before it's even pushed, and (b) as a new minimal Argo
WorkflowTemplate (`skills-validate`, added to `declarative-config`'s
`k8s/iad-ci/argo-workflows/`) triggered on push to this repo, so the check also runs
server-side for contributions that bypass the local hook. LLM-in-the-loop functional
self-tests (the `plan-review/SELF-TEST.md` style) remain manual runbooks — explicitly out of
scope for this harness — and are tracked as a separate follow-on (see beads filed alongside
this ADR).

### Considered Alternatives

#### Alternative A — Do nothing; keep relying on manual review before each commit
- **Pros:** zero effort, zero new files to maintain, matches current state.
- **Cons:** the repo has no author besides one person today, but it's public and accepts the
  premise that others may contribute or fork; manual review already missed the `$HOME` vs.
  `/home/coding` drift this audit found. Silent breakage is discovered by a user mid-task, in
  the worst possible moment to debug a skill.
- **Why not:** the cost of catching a broken reference or shell syntax error is a few seconds
  of `bash -n`; the cost of not catching it is a confused headless agent failing a real task.
  The asymmetry doesn't favor doing nothing.

#### Alternative B — Full LLM-driven functional test suite (run every skill against a fixture, grade the output)
- **Pros:** would actually validate the thing users care about — does the skill produce a good
  review/plan/postmortem — not just that the files parse.
- **Cons:** requires an LLM call per skill per run (14+ calls), needs fixture inputs and a
  rubric or LLM-judge per skill (doesn't exist for 13 of 14 skills today), is slow and
  non-deterministic enough to be a poor pre-commit gate, and mixing it with structural checks
  would make the fast/cheap check slow and flaky by association.
- **Why not:** this is real, valuable work, but it's a bigger and different investment than
  "does this repo's static structure make sense." Scoping ADR-1 to static-only keeps the
  harness fast enough to run on every commit; functional self-tests are tracked separately so
  they don't block on this decision.

#### Alternative C — Adopt an existing external skill-linter/framework instead of a bespoke script
- **Pros:** would avoid maintaining bespoke validation logic.
- **Cons:** as of this writing there is no established, widely-adopted linter for the Claude
  Code Skill frontmatter/directory convention this repo (and the workspace's own
  `~/.claude/skills/`) uses; adopting one would mean either building it anyway upstream or
  taking a dependency on a moving target for a ~150-line bash script's worth of value.
- **Why not:** the problem is small and well-bounded enough that a bespoke script is less total
  cost than vendoring and tracking an external tool for it.

### Consequences

- **Positive:** every future skill addition or edit gets fast (~sub-second, no network),
  dependency-light (bash + optionally shellcheck) feedback on structural mistakes before they
  ship. The pattern generalizes: adding skill #15 for free inherits the same checks. The
  drift-detection groundwork here (checking a skill's declared references resolve) is a
  prerequisite for the installed-copy drift checker filed as a follow-on bead.
- **Negative:** a new script to maintain, and a new convention (frontmatter must match a
  schema, `SKILL.md` references must be exact filenames) that slightly constrains how future
  `SKILL.md` files can be written — e.g. a checklist mentioned only in prose without its exact
  filename could false-positive as a broken reference and needs an allowlist escape hatch.
  Server-side enforcement depends on a new Argo WorkflowTemplate landing in
  `declarative-config`, which is a separate PR/sync in another repo, not something this commit
  alone delivers.
- **Follow-on work:** (tracked as beads, label `artifact-improvement`) shared bash utility
  library to deduplicate the 9 `score-*.sh`/`scan-*.sh` scripts; installed-copy drift checker;
  per-skill `version:` field + root `CHANGELOG.md`; root `install.sh` for selective,
  non-destructive installs into an already-populated `~/.claude/skills/`; extending
  `SELF-TEST.md`-style functional self-tests to `diff-review` and `repo-hygiene`; an SDLC
  lifecycle map doc chaining the 14 skills in invocation order.

### Reversibility / Cost to Change

- **Blast radius:** one new root-level script plus a hook-install script and (in a separate
  repo) one WorkflowTemplate. Deleting `scripts/validate-skills.sh` and the hook fully reverts
  this decision with no cleanup elsewhere in the repo.
- **Type:** two-way door — cheap to revisit. The checks are additive and non-destructive (no
  auto-fix in v1); disabling or loosening any individual check is a one-line change.
- **Reversal trigger:** if the false-positive rate on reference-integrity checks turns out high
  enough to make contributors bypass the hook routinely, narrow the check (e.g. checklist-file
  references only, drop the general link-scan) rather than removing the harness outright.

## ADR-2: 2026-08-20 — plan-review 2.0: a decision ledger replaces the header checklist

- **Status:** Accepted
- **Date:** 2026-08-20

**Decision: `plan-review` reviews a plan by the decisions it has not made, not by the section
headers it has.** The 83-item PRESENT / PARTIAL / MISSING checklist and its percentage score
are replaced by a decision ledger (every fork an implementer will hit, classified LOCKED /
ASSERTED / RECOMMENDED / SPIKED / DEFERRED / UNNOTICED / SHADOW, each open one resolved with
*Decision / Because / Rejected / Enforced by / Revisit if*), an implementer dry run, a reality
check against the real repo, seven safety caps, and a demoted, N/A-aware structural sweep. A
`--lock` mode writes accepted decisions into the plan's home sections. It runs inline.

**Because:** the header checklist measured the wrong thing. In this workspace 42 of 80
`plan.md` files carry ADRs, nearly all appended in the last 3–20 % of the file *after* the plan
had passed review; one plan scored "88 % present, 0 missing, READY" while its implementation
language was undecided and its first phase sat blocked for five days; another cached "every
2xx forever" with no staleness rule, which became a nine-day silent-staleness incident and two
contradictory ADRs. Every one of those ADRs is a fork the plan should have chosen. A corpus of
~340 planning documents shows the strongest plans rarely write standalone ADRs — they lock
decisions inline (Problem → Options → Decision → stop-ship Test), park open questions with a
recommended default and an answer plan, and turn un-armchair-able choices into dated spikes.

**Rejected:** (a) keeping the checklist and adding a "decisions" category — the percentage would
still reward length and still call an undecided plan READY; (b) a separate `decision-review`
skill — it splits one judgement across two contexts, and this workspace's own runs show
subagent fan-out costs ~67k tokens per agent with no quality gain; (c) grading with the
corpus's 100-point rubric — better than the checklist, but still a score, and scores invite
"88 %".

**Enforced by:** `plan-review/SELF-TEST.md` fixture with pinned `find-forks.sh` counts;
`scripts/validate-skills.sh` (frontmatter, references, syntax) on every commit via the
pre-commit hook; the functional-test invariant that the plan file is unmodified after a review
pass and modified only at a fork's home section after `--lock`.

**Revisit if:** a reviewed plan still spawns an ADR during implementation for a fork the
ledger catalog already contains — that is a catalog gap, fix `DECISION-LEDGER.md`; or if the
ledger's proposals are routinely rejected by humans — that is a taste gap, fix `EXEMPLARS.md`.
Either way it is a two-way door: the 1.0 bundle is one `git show <sha>:plan-review/` away, and
a tarball of the installed 1.0 copy was kept at
`~/.claude/backups/skills-plan-review-1.0.0-20260820-2335.tgz` before the install.

## Factory feedback loop: skills as the operator-side learning channel (2026-09-01)

The fleet's incident-to-rule pipeline is entirely manual today: an incident
becomes a memory by hand, a memory becomes CLAUDE.md prose by hand, prose
becomes a hook rule by hand-editing Python, and the review skills in this
repo run only when a human types them. Three changes close that loop from the
skills side; the NEEDLE side is NEEDLE plan section 4.4.

1. **`postmortem` emits a machine-readable lesson.** Alongside the prose
   postmortem it writes one `CandidateLesson` record (the shape defined in
   NEEDLE plan section 4.2: stable id, failure fingerprint, evidence
   references, proposed rule text, proposed gate or hook change, scope,
   expiry) to `docs/notes/lessons/<id>.md` with YAML frontmatter, so a lesson
   can be picked up by review rather than re-derived. The skill also gets
   installed by default; it is packaged today but not installed anywhere.
2. **Every review skill files beads.** `plan-vs-built` and `find-stubs`
   already create beads for their findings; `repo-hygiene` commits fixes but
   files nothing, so anything it cannot fix dies with the session. All three
   use the repo's declared bead backend (`bead_cli.backend` in
   `.needle.yaml`; `bead` for bead-rs, `bf` otherwise) and never write a
   `.beads/` file directly.
3. **Scheduled sweeps.** `scripts/install-review-timers.sh` installs systemd
   `--user` timers (the ex44 convention, like `bead-doctor-weekly`) that run
   `plan-vs-built`, `find-stubs` and `repo-hygiene` weekly over the
   configured workspace list with bead output, and a `memory-tool check`
   run whose failures land as a bead in the home workspace. Timers are
   idempotent to install and opt-in per host.

**Not in scope here:** automatic promotion of a lesson into CLAUDE.md, a
hook, or a gate. That stays a reviewed operation (NEEDLE ADR-027); these
skills produce the evidence and the proposal, never the policy.
