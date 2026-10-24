---
name: plan-vs-built
description: >-
  Compare what repos have ACTUALLY built -- binaries, tests that run, container tags,
  deployed manifests, live endpoints -- against what their plan.md says should exist, then
  create beads for the gap. Sweeps EVERY repo with a plan by default; narrows to one only
  when given a path. Classifies every plan deliverable as BUILT / UNPROVEN / PARTIAL /
  STUB / ABSENT / DIVERGENT / PLAN-STALE from observed artifacts rather than from prose,
  docs, commit messages, or closed beads; separately flags falsely-closed beads whose
  deliverable does not exist. Use when asked what's left to build, whether a project is
  really done, how far the code has drifted from the plan, or to turn that gap into
  tracked work.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Plan-vs-Built Skill

Inputs: `[repo-path-or-plan.md] [--create-beads] [--filter <regex>]`.

`plan-to-bead` asks "does every plan item have a bead?" This skill asks the harder
question: **does every plan item have a working artifact?** A repo can have a complete,
fully-wired, 100%-closed bead graph and still not build, not deploy, and not do the thing
the plan promised. Closure is self-reported; artifacts are not.

The default output is a per-deliverable verdict table backed by observations. Bead
changes require a scoped, explicit request; a fleet sweep alone is report-only.

## Step 1: Resolve the scope — **all repos is the default**

**With no path argument, sweep every repo under cwd that has a plan.** Keep the
discovery root at cwd; do not silently widen it to a home directory or filesystem
root. Do not ask which one. The question this skill answers — "is the plan actually
built?" — is a fleet-wide question, and asking the user to nominate a repo pre-selects for the projects they already
suspect, which are exactly the ones least likely to be hiding a silent gap. A repo nobody
has thought about in three weeks is the one whose plan has quietly drifted.

Resolution ladder:

| Input | Scope |
|---|---|
| no argument | **every** git repo under cwd with a `docs/plan/plan.md` or root `plan.md` |
| `--filter <regex>` | the subset of those repos whose basename matches |
| a repo dir or a plan.md path | that one repo |
| a plan.md already in conversation context | that one repo |

Ask the user for a **direction** only when repo evidence cannot settle a material
`DIVERGENT` decision (converge code or amend the plan). Choosing which repos to
inspect is already governed by the scope above.

Repos with no plan are silently out of scope; that is a scoping rule, not a finding. This
skill checks code against a plan, and inventing the plan from the code would make the
comparison circular. If a *named* target has no plan.md, stop and say so.

## Step 2: Sweep every repo for artifact reality

Resolve `SKILL_DIR` as the directory containing this `SKILL.md`, whether it is
installed for Claude or Codex or read from a checkout. Choose an output directory
outside every audited repo, then invoke the scripts relative to `SKILL_DIR`.
Keep the scan bounded to the intended cwd and use `--jobs`/`--depth` when the
candidate set is large:

```bash
AUDIT_OUT="$(mktemp -d "${TMPDIR:-/tmp}/plan-vs-built.XXXXXX")"
"$SKILL_DIR/scripts/sweep.sh" "$PWD" --out "$AUDIT_OUT"
# one repo only:
"$SKILL_DIR/scripts/collect-evidence.sh" "$TARGET_REPO" --out "$AUDIT_OUT"
```

`sweep.sh` discovers every git repo under the root with a plan, runs the collector against
each in parallel, and writes `index.json` / `index.tsv` plus a per-repo
`<out>/<repo>/snapshot.txt`. Useful flags: `--filter <regex>`, `--jobs N` (default 6),
`--depth N`.

Both scripts inspect source repos without changing them: they never build, run tests,
or mutate a bead store or cluster. They do write snapshots under `AUDIT_OUT`.
The collector reports repo/branch/dirty
state, plan files, build outputs (flagging any artifact **older than HEAD** — stale
evidence of a source tree that no longer exists), test-file presence,
`containers/*/VERSION`, where those images are referenced in `declarative-config`, Argo CI
templates naming the repo, tags, and the bead backend + status counts. It writes
`closed-beads.tsv` and `open-but-assigned.tsv` into each snapshot dir for Steps 7 and 8.

Two lines of its output do most of the work:

- **`ronaldraygun/<img>: NOT REFERENCED anywhere in declarative-config`** — built but
  never deployed. If the plan says it runs somewhere, that is a gap regardless of how
  green CI is.
  **Verify this one before reporting it.** It is a *name* match, and names drift: the
  image may be lowercase where the repo is not (`AIVC` → `ronaldraygun/aivc`), prefixed
  with the repo (`containers/aggregator` → `ronaldraygun/commitgraph-aggregator`), or on a
  different registry entirely (`ghcr.io/jedarden/sun-sim`). Search for the actual
  image reference in the configured `declarative-config` checkout; skipping that
  step is how a healthy deployment gets beaded as missing.
- **`VERSION=x.y.z` vs the pinned tag in declarative-config** — a version drift means the
  cluster is running something other than what the repo's HEAD describes. Note that hits
  containing `VERSION` or bare `with-deps` suffixes are Argo template *placeholders*, not
  real pins; read the referring file before calling either one a finding.

Also note the dirty-path count. **Uncommitted work is not built evidence** — it exists on
exactly one disk, no teammate or CI can see it, and on a shared NEEDLE checkout it may not
even be yours.

### Reference integrity — the highest-weighted signal

The collector runs `check-phantom-refs.py`, which parses tracked source (Python imports,
Rust `mod` declarations, JS/TS relative imports, HTML `src`/`href`) and reports references
that do not resolve to a tracked file:

- **`PHANTOM-REFS:n`** — tracked code points at a file that **exists on disk but is not
  tracked**. This is the worst state the sweep can find, and it is invisible to every other
  check: the repo works perfectly here, a fresh clone cannot build, review never sees the
  file, and deleting the working tree destroys the only copy. `dirty:N` does *not* catch it
  — an untracked file is only a problem when committed code depends on it.
- **`missing-refs:n`** — the target is absent on disk too. Usually a half-finished change
  that shipped: HTML rewritten to point at assets nobody vendored.

Both are near-zero-false-positive **once** you respect three asymmetries the checker
encodes, all of which cost real findings when got wrong:

- `vendor/` is skipped as a **source** (third-party files' JSDoc `@import`s are not your
  defect) but checked as a **target** (your HTML pointing into an unvendored `/vendor/`
  path is exactly the defect).
- A root-relative HTML URL resolves against the **site** root, usually `public/`, not the
  repo root — try every ancestor and treat the reference as satisfied if any resolves.
- A TypeScript `import './x.js'` is satisfied by `x.ts`.

Run it standalone on one repo with
`"$SKILL_DIR/scripts/check-phantom-refs.py" <repo>`; add `--json` for counts.

## Step 3: Rank the sweep, then declare how deep you actually went

The sweep prints a `SCORE` and `FLAGS` per repo. **These are not verdicts.** They are
mechanical signals — `undeployed`, `no-tests`, `all-closed`, `no-ci`, `unpushed`,
`stale-artifacts`, `backend-MISMATCH` — that rank *where to look*, because a verdict
requires an observation against a named plan deliverable and the flags have not read a
single plan. Reporting a flag as a verdict is the exact failure this skill exists to
prevent, one level up.

`all-closed` deserves specific suspicion: a repo whose bead graph is 100% closed is either
finished or falsely finished, and the sweep cannot tell which. That is Step 7's job.

Then work the per-deliverable pass (Steps 4–7) in score order, and **state the coverage
line in the report**:

> Swept N repos; full per-deliverable audit on M; triage-only on N−M.

A triage-only repo has **no verdicts** — say "not audited", never imply one. Silent
truncation is how a partial sweep gets read as a clean bill of health for everything it
never opened. If the run is bounded by time or budget, say what was dropped and give the
ranked list so the next run resumes rather than restarts.

For a fleet-scale sweep, prefer **depth over breadth**: a real verdict table for eight
repos beats a flag dump for eighty. The index persists on disk, so the next invocation
picks up where this one stopped.

## Step 4: Extract the plan's deliverables as checkable claims

Walk the plan and enumerate every thing it says will exist. For each, write down the
**observation that would settle it** before looking at any code — deciding the test after
seeing the evidence is how a wish becomes a verdict.

| Plan says | Settling observation |
|---|---|
| a CLI/binary/subcommand | run it with `--help`; the subcommand is listed and exits 0 |
| a library API/module | the symbol exists **and** a test or caller exercises it |
| an HTTP route/endpoint | a request returns the documented shape (curl locally, or the deployed URL) |
| a container image | `containers/<n>/VERSION` exists **and** that tag is pinned by a manifest |
| a deployment | pod Running in the named namespace, via the read-only kubectl proxy |
| a schema/migration/config | the file exists **and** something loads or validates it |
| a behavior/guarantee ("retries", "idempotent") | a test that fails if the behavior is removed |
| a doc/ADR/runbook | the file exists and describes what was actually built |

Record these as a ledger in the scratchpad (`deliverable | plan location | settling
observation | verdict | evidence`), one row per deliverable. Keep plan section/line
references — Step 9's beads need them, and a bead that can't point at its plan clause
invites someone to re-litigate the scope.

In a multi-repo sweep, keep one ledger **per repo** (`<out>/<repo>/ledger.md`). Deliverable
names collide across repos ("the exporter", "the dashboard"), and a merged ledger is how a
verdict from one repo ends up cited as evidence in another.

## Step 5: Gather evidence — cheapest first, and mind the environment's traps

Work up the ladder and stop as soon as a verdict is settled:

1. **Existence** (`rg`, `git ls-files`) — cheapest, and only ever proves shape.
2. **Builds** — `cargo build`, `go build ./...`, `npm run build`, `tsc --noEmit`.
3. **Exercised** — is there a test that would fail if the deliverable vanished?
4. **Runs** — execute the binary, curl the endpoint, load the module.
5. **Deployed** — the read-only kubectl proxy for the cluster in question.

If the user requested a read-only audit, use existing build, test, CI, and runtime
evidence rather than starting builds or tests. Record what could not be proved as
`UNPROVEN`; do not turn a read-only request into a bead or repository write.

Environment traps that will otherwise produce a false verdict:

- **`cargo test` is intercepted** on this box and submits to iad-ci via `rust-verify`.
  Do not fire it off as a casual probe. For a local signal use `cargo build`,
  `cargo nextest run` (runs locally under cgroup limits), or read the last CI run's status
  instead of starting a new one.
- **kubectl is read-only** through the proxies, and mutating verbs are both prohibited and
  hook-blocked. `get`/`describe`/`logs` answer every question this skill needs. Never
  "just restart it" to check something.
- **A green CI run proves the tests passed, not that the tests test anything.** If the
  plan promises a behavior and the only test asserts a constructor returns Ok, that is
  UNPROVEN, not BUILT.
- **`/find-stubs` is the right tool for one sub-question** — whether a symbol that exists
  is actually implemented. Run it when existence checks pass suspiciously easily; a
  `todo!()` behind a real signature is the single most common way a deliverable looks
  BUILT and is ABSENT.
- **Don't let a doc vouch for code.** A README, an ADR, a commit message, and a closed
  bead are all self-report. They describe intent at the moment of writing.

## Step 6: Assign a verdict per deliverable

| Verdict | Meaning | Direction of fix |
|---|---|---|
| `BUILT` | artifact exists, is current, and something exercises it | none |
| `UNPROVEN` | it exists and compiles, but nothing tests, runs, or deploys it | propose proof work |
| `PARTIAL` | some named sub-pieces present, others missing | propose the missing pieces only |
| `STUB` | signature/route/file exists, body is placeholder | propose implementation |
| `ABSENT` | nothing in the tree corresponds to it | propose build work |
| `DIVERGENT` | something was built, but not what the plan describes | **ask** — converge code, or amend plan |
| `PLAN-STALE` | reality is right; the plan is out of date or was superseded | propose a plan correction, **no bead** |

`UNPROVEN` is not a lesser `BUILT`. Untested, unwired, or undeployed code is the specific
state this environment keeps rediscovering the expensive way, and it is worth its own bead
with its own acceptance check.

**The last two verdicts are why this skill asks before it writes.** A gap can mean the code
is behind the plan *or* that the plan is behind the code — a deliberate descope, a
superseded design, an ADR that changed direction. Beading phantom work is the main way
this skill can do damage: it manufactures work that a fleet will dutifully perform. When
the direction isn't obvious from the repo's own history (check `docs/adr/`, `docs/notes/`,
and the commits around the divergence first), ask the user rather than guessing.

## Step 7: Audit the closed beads against the verdicts

This is the step no other skill performs, and usually the highest-signal one.

For every deliverable that landed `ABSENT`, `STUB`, or `UNPROVEN`, search
`closed-beads.tsv` for a bead that claimed it. Each match is a **false closure**: work
recorded as finished that produced no artifact. Report these separately and by ID — they
are a different problem from an un-started deliverable, because the tracker actively says
they are done and nobody will look again.

Root cause here is structural, not incidental: acceptance derives from the agent's own
exit status (`classify(0,false) == Success`), so a worker that exits cleanly without
building anything is recorded as a success. Expect false closures in any repo a fleet has
worked; treat zero of them as a claim to verify, not a relief.

Report false closures with bead IDs and evidence. Reopen only when the user explicitly
authorizes restoring that already approved work; reopening can put it back on the
autonomous frontier. As of 2026-08-24, `bead reopen` clears the assignee automatically.
Verify visibility after an authorized reopen:

```bash
bead reopen <id>
bead list --ready | grep <id>         # verify it actually surfaced
```

**A separate, still-real trap:** a bead can be `open` *with* a stale assignee through a
different path entirely — a crashed or renamed worker, not a reopen (root cause: NEEDLE's
Mend strand skips any assignee whose worker *name* is still alive, and a relaunched
worker under the same name keeps it stuck forever; see NEEDLE bead `needle-44e7e5cd`).
This state is silent — `bead show` and `bead doctor` both report it as healthy — and
`bead release` will not fix it; it refuses an assigned-but-open bead by design. Clear it
directly:

```bash
bead update <id> --clear-assignee
bead list --ready | grep <id>
```

The snapshot's `open-but-assigned.tsv` lists candidates. Report them separately;
clear an assignee only when the existing work and its ownership are verified and the
request authorizes that operational change.

Prefer reopening the original bead when its description still describes the right work.
Write a **new** bead instead when the original's description is wrong or vague — bead-rs
cannot edit a title or description after creation, and `bead update --notes` is write-only
with no read path, so a correction recorded as a note is invisible to whoever picks it up.

## Step 8: Ground the bead backend before writing anything

Detect, never assume — Step 2's snapshot already printed both the on-disk shape and what
`.needle.yaml` declares:

- `.beads/config.json` + `.beads/checkpoint/` → **bead-rs** (`bead`)
- `.beads/config.yaml` + flat `.beads/issues.jsonl` → **legacy bf**
- No `.beads/` → no bead workspace; initializing one is a separate scoped write

Running the wrong CLI against a store does not fail cleanly — it reports a generic SQLite
column error, and applying the other tool's recovery recipe to that silently reinitializes
the store with the wrong schema and destroys live data. If the snapshot printed a MISMATCH,
or the store is bf-shaped (`bf` is decommissioned on this box and not on PATH), stop and
report it blocked rather than improvising.

If a legacy backend must be written, consult the repository's current supported
command map and verify argument order before any mutation.

## Step 9: Create the gap beads (only for an explicitly authorized scope)

The default audit, including a fleet sweep, writes no beads. `--create-beads` on a
named repo or an explicit request naming repos authorizes proposal creation there.
With no named repo, present a batch with exact repo, gap, and acceptance boundary,
then get explicit admission of the target set before changing any bead store. Silence
does not admit a batch. Do not create beads for decisions or confirmed `PLAN-STALE`
items; resolve `DIVERGENT` direction first.

**Dedup first.** Read all existing beads (`bead list --json --limit 999999`) and
check open and in-progress owners. If one already covers a gap, record the
match and move on — a duplicate bead is not a tracking
nit here, it is two fleet workers doing the same work twice and racing on the same files.

Each new bead gets, at `create` time (bead-rs cannot edit any of this afterwards):

- **One outcome owner.** Split only independently actionable deliverables or real
  dependencies. Include the tests, documentation, verification, and delivery
  necessary for that outcome; do not split by title grammar or implementation steps.
- **The plan clause it restores**, by section and line.
- **The evidence of the gap** — what you looked for and what you observed. Not "not
  implemented" but "`bead why --id` referenced in docs/plan/plan.md:412; no `why`
  subcommand in `src/cli/`; `bead --help` lists 14 subcommands, `why` not among them."
- **A `## Done when` written as an observation someone else can reproduce** — a command
  and its expected output, not a feeling. This is the whole lever against
  acceptance-by-self-report: `curl -s localhost:8080/healthz | jq -e .ok` is checkable;
  "endpoint works" is not.
- **No local-only acceptance criteria.** Fleet workers share no filesystem, so "the
  artifact is at /home/coding/… on ex44" is unverifiable for whoever claims it — and
  pushing the artifact into git to compensate is how a repo ends up with 817MB of history.
  Name a committed path, a released tag, or a live endpoint.

Write the plan clause, observed evidence, and reproducible `## Done when` check
to a task-specific scratch file, then pass its path to the CLI:

```bash
bead create --title "..." --issue-type task --priority 2 \
  --label plan-gap --label proposal-pending --label human \
  --description-file <scratch>/gap-description.md
```

Label them consistently (`plan-gap`, `proposal-pending`, and `human`). Keep both hold
labels until an explicit batch admission of exact bead IDs; creating or flushing a
proposal does not admit it to the ready frontier. Wire
real blocking edges where one gap genuinely prerequisites another (`bead dep add
<BLOCKED> <BLOCKER>`), and prefer a blocker over prose — an edge is enforced, a sentence
is not.

Verdict → bead mapping: `ABSENT`/`STUB`/`PARTIAL` → build it. `UNPROVEN` → prove it (its
own bead: add the test, wire the caller, pin the image, deploy it). `DIVERGENT` → only
after Step 6's decision. `PLAN-STALE` → no bead; apply a plan correction only when
that edit is within the authorized scope.

## Step 10: Flush, commit, report

Run the flush and commit path only in repositories where writes were authorized and
made. A report-only run leaves every repo and bead store unchanged.

```bash
bead sync flush-only
git status --short .beads
# Stage and commit only the exact checkpoint/config paths changed by this run,
# including any new checkpoint objects referenced by current.json.
```

Inspect the index before committing, preserve unrelated staged changes, and stage
precise paths. Pass those same paths to `git commit` so a sibling worker's staged files
are not swept into the commit.
`.beads/beads.db` is live SQLite and is never committed. Check `git log -1` and
`git status --porcelain .beads` afterwards to confirm what landed.

In a multi-repo sweep, flush and commit **per repo**, as you finish that repo — not in one
pass at the end. A sweep that dies halfway through then leaves nothing behind, and each
repo's checkpoint belongs in its own commit anyway.

Report, in this order:

1. **The coverage line.** `Swept N repos; full audit on M; triage-only on N−M.` First,
   because every number after it is scoped by it.
2. **The cross-repo roll-up** — one row per audited repo: deliverables, `BUILT`, gaps,
   false closures, headline finding. This is what makes a fleet sweep readable; a reader
   scanning eighty repos needs the shape before the detail.
3. **The verdict table per audited repo** — every deliverable, its verdict, and the
   observation behind it. A verdict with no observation next to it is the failure mode
   this skill exists to prevent; write "not checked" rather than implying evidence you
   don't have.
4. **Counts by verdict**, and the honest headline: `N of M plan deliverables are BUILT`.
5. **False closures by bead ID** — the beads that said done and weren't.
6. Beads created (with IDs), beads reopened + assignee-cleared, and any deduped against
   existing work.
7. Anything deliberately *not* beaded, and why (plan-stale, descoped, awaiting a decision).
8. **The triage-only remainder**, ranked, with its flags — labelled as unaudited, so the
   next run resumes from the top of that list.

## Key Principles

- **All repos is the default scope.** The gaps worth finding are in the projects nobody
  nominated. Narrow only when the user names a target.
- **A triage flag is not a verdict.** The sweep ranks where to look; only an observation
  against a named plan deliverable settles anything. Never let a flag dump read as an audit.
- **"It works here" is the weakest possible evidence.** A repo whose tracked code imports an
  untracked file passes every local check and fails for everyone else. Prefer observations
  made against a *fresh clone*, not against the working tree that authored the code.
- **An artifact is evidence; a claim is not.** Source files, commit messages, READMEs,
  ADRs, green CI, and closed beads are all statements of intent. A binary that runs, a
  test that fails when you break the thing, a pod that answers — those are observations.
- **Decide the settling observation before you look.** Written after the fact, the test
  bends to match whatever was found.
- **Closed does not mean built, and a fleet-worked repo will prove it.** Acceptance
  derives from a worker's exit status, so "exited cleanly having done nothing" reads as
  success. Audit closures against artifacts every sweep.
- **A gap has a direction.** The code can be behind the plan or the plan behind the code.
  Beading phantom work is worse than missing a gap, because a fleet will actually do it.
- **`UNPROVEN` is a real verdict, not a soft pass.** Built-but-unwired and
  built-but-untested are exactly the states that survive review and fail in production.
- **Report false closures before changing the graph.** Reopen or clear an assignee only
  within an authorized scope. `bead reopen` clears the assignee automatically; a bead
  left `open` with a stale assignee needs a separate, verified correction.
- **Detect the bead backend, never assume it.** The wrong CLI against a store corrupts it
  rather than erroring, and the "recovery" makes it worse.
- **Never mutate a cluster to test a hypothesis.** Read-only verbs answer every question
  here, `selfHeal` reverts live edits anyway, and the hooks will block you.
