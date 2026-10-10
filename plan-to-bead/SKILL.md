---
name: plan-to-bead
description: >-
  Decompose a plan.md into a fully-wired bead dependency graph via the repo's own bead
  CLI after detecting its backend -- one owner per outcome, dependencies matching
  the plan's real technical relationships, verified for coverage, scoping and
  dependencies with bounded review. Preserve a repository-required genesis summary
  without using it as a substitute for concrete owners. Also runs as a standalone audit against a repo that
  already has a full bead graph for its plan, to check and fix it without
  creating duplicate beads. Use when the user wants to turn a plan or spec into
  trackable, properly-scoped beads, or wants an existing bead graph checked for
  coverage/scoping/dependency correctness against its plan.md.
argument-hint: "[path/to/plan.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion
---

# Plan-to-Bead Skill

Turn the authorized parts of a plan into a dependency-wired graph, with one owner
per independently deliverable outcome. Keep necessary implementation, tests,
documentation, verification, and delivery together. Verify coverage, ownership
boundaries, and real dependencies. Use `outcome-work` for substantial delegated work:
pass paths and constraints to a bounded child, keep the parent out of full tool logs,
and return Result / Evidence / Remaining / Decision / Next.

## Admission and existing decisions

Turning an approved plan into beads does not require repeated permission for routine
choices or necessary prerequisites. Honor settled choices and existing authorization.
New proposals or expanded acceptance boundaries need one concrete batch review with
exact admit/reject/defer ID lists, recommendations and exceptions. Keep both `human`
and `proposal-pending` on unapproved proposal beads; only apply explicitly approved
dispositions. A request to organize a plan is not permission to self-admit new ideas.

## Hard rule: never create a decision bead

**A bead is a unit of work a worker executes. An unresolved decision requiring user
authority must never become a fleet-claimable bead** -- not with a `decision` label, not with a `DECISION:` title,
not disguised as "Choose X" or "Determine whether Y". This is absolute and applies to
drafting (Step 3), to coverage fixes during verification (Step 6), and to anything the
genesis bead records (Step 9).

The reason is what a bead *is for*: beads are claimed autonomously, often by fleet
workers. A worker that claims "DECISION: primary source for the study" makes a judgment
call with no authority to make it, and the graph then reads as though the question were
settled. A decision bead also cannot be worked to completion -- there is no artifact, no
test, and no way for the worker to know it chose right.

**Where forks requiring user authority go instead:** the plan's own **Open questions** section, one
entry each, carrying the fact that forces the question and a proposed answer where one
exists. That is a document a human reads and edits, which is what a decision needs. If
the plan has no such section, add one. Record the question there *before* removing or
declining to create the bead, so the fork is never simply dropped.

**What is still a legitimate bead**, and must not be confused with a decision:

- a **probe or spike** -- "Run the column-projected-read spike and record its
  measurements". It produces data. Its output is an artifact, and the judgment it feeds
  stays with the human.
- **sourcing or authoring an artifact** -- "Source and commit the pinned NYSE calendar".
  Choose a source within approved constraints; only a material unresolved authority
  or outcome question belongs in Open questions. Fetching and committing it is work.
- **recording a disposition already decided** -- "Update the parity matrix rows to done
  or explicitly excluded".

A frontier made of decision beads is the failure mode this rule exists to prevent: it
looks like a ready graph while nothing in it can actually be started.

## Step 1: Resolve the target plan.md

Same resolution ladder as plan-gap-review: explicit path argument > one plan.md already in
conversation context > exactly one `docs/plan/plan.md` under cwd > AskUserQuestion if
ambiguous or not found. Read it in full.

## Step 2: Ground -- workspace, tool, and readiness

- **Determine which backend this repo uses before typing a single bead command.**
  Repos migrate one at a time, and running the wrong CLI against a store does not fail
  cleanly -- it can silently corrupt the other tool's schema. Detect, never assume:
  - `.beads/config.json` + `.beads/checkpoint/` -> **bead-rs** (`bead`)
  - `.beads/config.yaml` + a flat `.beads/issues.jsonl` -> **legacy bf**
  - `.needle.yaml` with `bead_cli: backend:` states it explicitly
  - No `.beads/` at all -> greenfield, use the canonical CLI below if tracking
    initialization is within the requested scope
- **Canonical for new workspaces is `bead` (bead-rs)** as of 2026-08-14, per CLAUDE.md;
  `bf`/`bead-forge` and the older `br` alias are retired for active work. For a
  greenfield repo: `bead init --prefix <short-repo-prefix>` (derive the prefix from the
  repo name, never leave the default "bead"). Verify current init help first. If
  metadata disagrees, inspect the actual configured backend and store without repair;
  escalate only if the backend cannot be established safely.
- **An existing store's backend wins over the canonical default.** A bf-backed repo stays
  on `bf` for this run; migrating it is separate work, never a side effect of beading.
- Check readiness: does the plan specify enough for each phase to decompose into concrete
  work, or are whole sections still "TBD"? If so, say so and suggest `/plan-gap-review` or
  finishing the plan first, rather than beading vague scope -- a vague bead invites
  duplicate or conflicting work later. Proceed with independently well-defined
  authorized sections while collecting material open questions in one batch.
- Inspect the detected CLI's current help and capabilities before copying commands.
  If the workspace already has beads from prior work, read their descriptions, notes,
  labels and dependencies using that backend's structured output -- this is not a minor caveat. If the plan is already fully beaded,
  this run's job is almost entirely Step 6's verification loop against what already
  exists, with little or nothing new to draft. Keep this list at hand for Step 3's dedup
  check and Step 6's coverage check.

### Installed CLI, durable notes, and atomic creation

On bead-rs, the installed CLI is authoritative. Check `bead --help`,
`bead create --help`, `bead manifest --help`, and the relevant subcommands.
Current supported operations include:

- `bead list --json --limit N`: JSONL, one object per line, including dependencies.
- `bead show ID --json`: detailed output; inspect its actual shape before parsing.
- `bead why --id ID`: explain blockers and readiness.
- `bead create ... --depends-on BLOCKER`: attach an existing blocker atomically.
- `bead manifest dry-run --input FILE` then `bead manifest commit --input FILE`:
  all-or-none create/update/label/dependency mutations, with local IDs for new nodes.
- `bead dep add BLOCKED BLOCKER`: blocked-first argument order.
- `bead update ID --notes TEXT`: readable notes, replacing the current notes field;
  retain useful existing evidence and use revision guards for concurrent writers.
- `bead label add|remove`: labels are handled separately from `update`.
- `bead close ID --reason TEXT`: close only after the owner's acceptance is satisfied.

Successful mutations normally publish and stage the durable checkpoint automatically.
Check configuration; run `bead sync flush-only` when manual publication is enabled.
The live `.beads/beads.db` is not committed. For a detected legacy store, verify its
own installed command help instead of translating bead-rs arguments by guesswork.
Do not add legacy recipes to new active workflows or migrate a store in this task.

## Step 3: Draft the task list -- decompose, don't transcribe

Walk the plan's implementation phases/sections and enumerate distinct units of work, as a
draft in your own reasoning or a scratch file first -- not beads yet. This is a *first
pass*, not the final word -- Step 6 exists specifically because a first pass, even a
careful one, misses things.

For each candidate, identify its concrete outcome, acceptance boundary, owner and
real prerequisites. Split independent deliverables or dependencies that can be
owned separately. Do not split by title grammar, phase count, or the number of
implementation steps. Necessary tests, documentation, verification and delivery
belong to the implementation owner; a child agent does not need a separate bead.

**Apply the decision filter.** Routine reversible implementation choices belong to
the worker within the authorized outcome. A material fork affecting scope, authority,
cost, or the user's intended result goes into Open questions with a recommendation,
not a fleet-claimable decision bead. Work dependent on that fork must remain held
until it is resolved. Do not convert an unresolved decision into apparent approval
by creating an implementation bead without the corresponding hold.

Before accepting a candidate task, check it against Step 2's pre-existing bead list. If
an existing bead already represents that unit of work, don't draft a duplicate -- record
the match (candidate <-> existing bead ID) so Step 6 verifies *that* bead's scoping and
edges instead of Step 4 creating a redundant one. Only genuinely uncovered units of work
become new-bead candidates. This is what makes a run against an already-fully-beaded
repo behave as a pure audit rather than a pile of duplicates.

## Step 4: Create the initial bead graph

If Step 3's dedup check left zero new candidates -- the plan is already fully beaded --
skip straight to Step 6 against the existing graph as-is. That's a fully supported
verify-only run, not a degenerate case: most of this skill's value on a repo that
already has beads is Step 6 catching scope and dependency problems the original
decomposition missed, exactly like the DEPENDENCY-category findings in this skill's own
worked example. Otherwise, for the genuinely new candidates:

On bead-rs, build a versioned manifest in a task-specific scratch file. Inspect
current manifest help/schema, validate with `bead manifest dry-run --input FILE`,
then commit it atomically. Include the intended proposal holds, assignments and
blocker edges in that transaction so workers cannot claim a half-wired graph.
Capture the committed local-ID/result map for subsequent verification; dry-run IDs
are provisional. A single dependent may use `bead create --depends-on BLOCKER`.
If this installed version lacks atomic manifests, use a supported unclaimable
staging state for every new node, wire and verify it, then admit only authorized
work. Never publish ready nodes and add blockers in a second command.

On an existing legacy store, use its supported atomic or held-staging mechanism
as verified from current help. Do not reinitialize it to obtain bead-rs features.

Block each bead on the *specific* thing it needs, not the nearest phase-level umbrella
when a finer-grained blocker already exists or is being created in the same run. Wire
any pre-existing beads (Step 2) that relate to the new decomposition at this point too.

Ensure the detected backend's durable checkpoint is current after mutation; on
bead-rs use `bead sync flush-only` when publication is manual. Verify the graph below.

## Step 6: Bounded independent verification

For a substantial graph, use one independent review child with paths to the plan
and a complete structured graph snapshot in scratch, plus scope and authority.
Use its own context rather than pasting the parent transcript. The child checks:

- **Coverage:** every authorized plan outcome has an owner; intentional exclusions
  and unresolved authority questions are explicit, not silently dropped.
- **Scoping:** each bead owns a concrete deliverable, including its necessary tests,
  documentation, verification and delivery; no duplicates or evidence-only children.
- **Dependencies:** every stored blocker is a real prerequisite and no real blocker
  is missing. Pending proposals and unresolved user decisions remain held.

Return concrete findings with category, severity, bead IDs/plan locations and
suggested corrections; return concise evidence if none. Do not manufacture issues.
Use complete structured inputs so omitted edges cannot appear as a clean graph.

Fix real findings within the authorized scope. Queue scope expansions for one batch
admission; keep genuinely unresolved forks in Open questions. Recheck changed nodes,
their dependency impact and any previously failed properties. Broaden review only
when changes or unresolved risks justify it. Honor stricter repository review gates.
One clean required review is sufficient when inputs have not changed; do not spawn
another reviewer merely to accumulate consecutive clean rounds. Cosmetic suggestions
that do not affect acceptance do not require a user interruption. If substantive
issues remain at the task's operating budget, record them and the exact next action
on the owner; do not claim verification complete.

## Step 7: Verify the mechanics, not just the content

Check the final stored graph and actual ready frontier, not merely the proposed
manifest. On bead-rs use structured list output, `bead why --id ID`, and installed
`bead analyze-exclusion` when available. Check roots and dependent nodes against
actual prerequisites; implementation work may legitimately be a root when it has
no prerequisite. Pending proposals and work awaiting a material user decision must
not be claimable. Detect decision-shaped beads by their content, not just titles.

If an existing decision bead is invalid, preserve the unresolved question on its
owning plan/bead, hold dependent work, and safely rewire before closing the invalid
node. Closing it alone would falsely signal resolution to dependents. Do not relax
holds to make the frontier look ready. For legacy stores, verify readiness against
stored blockers using the supported backend; do not trust stale output examples.

## Step 8: Splitting a bundled bead (invoked from Step 6's fix pass, or any time a scope violation is found)

Closing a bundled bead does *not* safely remove it from the graph: a closed bead
satisfies its dependents' blocking condition, so closing without first rewiring
dependents makes downstream work falsely appear ready before the replacement work exists.
Order matters:

1. Prepare replacement beads and all rewiring in one atomic manifest when supported.
   Otherwise create replacements in an unclaimable staging state, with their correct
   internal dependencies. Preserve proposal holds and existing ownership.
2. Find every dependent from current structured graph output, including nodes outside
   the immediate phase. Inspect current CLI support instead of assuming a reverse-edge
   query exists or does not exist.
3. For every dependent, add edges to whichever specific replacements it needs before
   removing its bundled-node edge (or change all edges atomically);
   re-apply Step 3's ownership criteria to figure out which piece each dependent really needs. This is
   also where bundling tends to reveal dependency errors the bundle was hiding -- fix
   those too while rewiring, not just the split itself.
4. Only after every dependent is rewired, `close <bundled-id> --reason "Superseded:
   split into <replacement-ids> -- <why>"`.
5. If the genesis bead (Step 9) already existed and was blocked on the bundled bead,
   rewire it the same way, plus a note (see Step 9).

## Step 9: Genesis bead -- created last, as a fallback

If the repository already requires a genesis/planning summary, update or create it
after substantive verification. Do not create one solely to inflate activity or
repeat acceptance evidence. Point its body at the plan and live blockers; record
material decisions, graph changes and deliberate deferrals in readable notes. Use
the detected backend's current issue-type and dependency syntax. Block it on the
actual deliverables needed for its stated outcome and keep proposal holds intact.

## Step 10: Checkpoint, deliver and report

Keep the owning bead current with affected paths, admission decisions, actual
verification commands/outcomes, remaining checks and commit references. Ensure its
durable checkpoint is current. Inspect `git status --short` and stage precise owned
paths; do not include unrelated staged changes or the SQLite store. Commit and push
through the repository's configured flow when authorized.

Report the concrete graph outcome, material corrections, verification evidence and
remaining user decisions. Counts may support the report; they are not the outcome.
Return a compact result to the parent rather than the full graph or reviewer logs.
