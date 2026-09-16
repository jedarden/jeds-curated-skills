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

Distribution today is `git clone` (whole repo) or `./install.sh <skill>` (single skill) into
`~/.claude/skills/`, per README.md — since 2026-09-15 the installer, not a bare `cp -r`, is the
documented single-skill path, because repo scripts source the shared `lib/common.sh`, which the
installer inlines so each installed skill is self-contained. One skill, `usage-statusline`, has a genuinely live
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

**Update 2026-09-15 — the script-bearing skills now have a regression net.** Every skill
carrying a `score-*.sh`/`scan-*.sh` script has a `SELF-TEST.md`: `plan-review` (fixture with
pinned `find-forks.sh` counts, per ADR-2), `diff-review` and `repo-hygiene`, and now
`spec-review`, `plan-author`, `readme-review`, `api-design-review`, `test-plan-review`, and
`release-readiness`. Each pins its script's happy path against an inline heredoc fixture with
exact expected counts (score, MISSING list, per-style inventory, exit codes) plus documented
grep quirks, so the `lib/common.sh` extraction has a before/after net — the scripts test from
a repo checkout, since installed copies lag and score scripts source `../../lib/common.sh`.
The functional, LLM-in-the-loop sections remain manual runbooks.

**Update 2026-09-15 — every skill now has a SELF-TEST.md.** The last seven
uncovered skills are covered in two shapes matched to their surface. The six
prose-only skills (`adr`, `migration-runbook`, `plan-gap-review`, `plan-idea-gen`,
`postmortem`, `threat-model` — checklists and flows, not scripts) each got a
manual runbook built around a **fixture document with a planted-defect/expected-
findings inventory**: a weak ADR pinned to 4 PRESENT / 3 PARTIAL / 5 MISSING with
a named STRAWMAN, an unsafe migration runbook that must fail all five
non-negotiables (0/1/11), a plan with seven enumerable gaps plus a clean-doc
control for the loop's exit condition, an ideation run whose pins are mechanical
(inline-only tool list, ambiguity STOP, ledger append, content-shape), a
blameless-violation draft pinned to 0/1/13 plus a shell-verifiable
CandidateLesson hash check (`sha256(fingerprint+scope)[:16]` = filename), and a
thin threat model pinned to 3 PRESENT / 6 PARTIAL / 6 MISSING. Mechanical pins
(quote-the-line violations, blank cells, totals) are hard; judgment items may
flex one step with an argument — a moved hard pin means the checklist changed
deliberately. `usage-statusline` got a **scriptable smoke test** that runs the
statusline script against a fixture `$HOME` (no creds ⇒ no network path) and
asserts exit 0 + a single non-empty line with no trailing newline (byte-checked),
pinned window labels/percents, and the async commit-count warm (run 1 pins the
`⎇` segment only — the background scan races the first render — with the pinned
`⎇ 2` on run 2 after a bounded wait on the warmed cache); degraded-cache cases
pin missing-cache ⇒ silent exit 0,
empty/shapeless cache ⇒ non-zero exit through `set -u` (the `eval` masks jq's
status, so the `|| exit 0` guard is dead code for that path — pinned as a known
quirk, not silently "fixed"), stale cache ⇒ renders stale values, and
no-`weekly_scoped` ⇒ third window omitted.

**Update 2026-09-16 — the regression net gained a coverage ratchet.** Replaying
pins is only half a net: `scripts/test-script-fixtures.sh` failed when a pin
*drifted*, but nothing failed when a new `score-*`/`scan-*`-class script shipped
without one — the pre-2026-09-15 "ships silently" failure mode re-opened for
future scripts. The suite now enumerates every skill script in the fixture
families (`score-*`, `scan-*`, `find-*`, `collect-*`, `*_hygiene.sh`) and fails
unless each is replayed there (a `skill_script <skill> <script>` call site is
the pin) or listed in its `FIXTURE_EXEMPT` with a reason — a count floor keeps
the enumeration itself from going blind. The ratchet's first run caught the one
live gap: `plan-review/scripts/scan-headers.sh` was wired into SKILL.md but
never pinned; it now has a fixture (same document as `find-forks.sh`, so both
plan-review scripts are pinned against one byte-identical input) that also pins
the `grep -c || echo 0` doubled-zero quirk of the shared header-count helper as
known behavior. `plan-review/scripts/score-plan.sh` — deprecated and
unreferenced — is the one exemption. Known remaining gap, recorded here so it is
not rediscovered: `lib/common.sh` still has no direct unit tests; its helpers
are pinned only where the script fixtures happen to exercise them, and a direct
lib test is blocked on the lib extraction landing (the fixture suite
deliberately holds against both the pre- and post-extraction trees, so it
cannot source the lib itself).

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

## ADR-3: 2026-09-15 — ShellCheck lint pass with a committed baseline ratchet

- **Status:** Accepted
- **Date:** 2026-09-15

**Decision: scripts are held to a lint bar, not just a parse bar.** ADR-1's harness proves a
script *parses* (`bash -n`); it does not lint it. `scripts/lint-shell.sh` runs ShellCheck over
every shell script in the repo (root `*.sh`, `lib/*.sh`, `scripts/*.sh`, every skill's
`*/scripts/*.sh`; SC1091 excluded as signal-free with follow-sourcing off) and enforces the
committed baseline `scripts/shellcheck-baseline.txt`: each finding is keyed
`<repo-relative-path>|<SCcode>` and counted — a count above baseline fails, a count below is an
improvement (`--refresh` shrinks the baseline). It wires into `validate-skills.sh` as check #5,
repo-wide, on full-repo runs only (a targeted single-skill run must not fail on another skill's
lint state; the pre-commit hook always runs full-repo, so commits are always gated). Without a
`shellcheck` binary on PATH the lint exits 0 with a skip notice — the ADR-1
dependency-tolerance rule stands, since shellcheck is still not installed on this machine
(NixOS: `nix shell nixpkgs#shellcheck -c scripts/lint-shell.sh`).

The baseline records known, accepted debt with hand-maintained justifications that survive
`--refresh`: the `eval "$(jq -r ...)"`-assigned variables in `usage-statusline` (SC2154, ten of
them, unfixable without dropping the jq eval pattern), the redundant-but-correct `case` arms in
`scan-release.sh` (SC2221/2222), the load-bearing single-quoted sed/jq programs in
`test-root-scripts.sh` (SC2016 — the sed script must insert a literal `$(dirname "$0")` into an
installed copy; jq binds `$cmd` via `--arg`), and its `trap`-invoked `cleanup` (SC2329).
Fix-everything-instead-of-baselining was rejected: several findings are false positives by
construction, and suppressing them inline in nine skills' scripts would scatter lint
plumbing through skill code that ships to users.

The baseline is generated by, and version-stamped with, ShellCheck 0.11.0 against the
committed tree — counts shift between ShellCheck releases, so a version mismatch warns at
check time. Server-side, the `skills-validate` WorkflowTemplate runs `alpine/git`, which has
no shellcheck, so the lint stays dormant there until that template installs a matching pinned
version (tracked with the template's own bead); the pre-commit hook is the enforcing gate
today.

**Revisit if:** a ShellCheck upgrade lands server-side with shifted counts — refresh the
baseline in the same change that bumps the template's shellcheck, and diff the entry delta as
the review artifact; or if new findings routinely arrive with "just refresh it" justifications —
that is the ratchet being gamed, and the response is fixing findings, not widening the
baseline.

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
