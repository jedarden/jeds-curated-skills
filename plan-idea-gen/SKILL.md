---
name: plan-idea-gen
description: >-
  Generate a large pool of ideas (default 100) for a project anchored to its plan.md, then
  ruthlessly filter to the top K (default 10) via lens-forced generation, clustering,
  pairwise ranking, and an adversarial kill pass — all inline in a single context (no
  subagents). Winners become dossiers, ledger entries, and optionally bf beads. Use when
  the user wants to brainstorm, ideate, expand a roadmap, or asks for "best ideas" /
  "top N ideas" for a project or plan.
argument-hint: "[plan.md path or repo] [--pool N] [--keep K] [--constraint \"...\"] [--lens \"...\"]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet
---

# plan-idea-gen — wide-then-narrow ideation anchored to a plan.md

Generate POOL ideas (default 100) across forced-diversity lenses, then filter to KEEP
finalists (default 10) that survive clustering, pairwise ranking, and an adversarial
kill pass. Every run is anchored to exactly one plan.md: it grounds generation, hosts
the ledger, decides the bead workspace, and receives accepted ideas.

## Execution model: ONE context, no agents — MANDATORY

The entire pipeline runs **inline in the invoking context as sequential reasoning
passes**. Never use the Workflow tool. Never spawn Agent subagents — not for
generation, not for judging, not even an Explore scout. This is a hard rule, not a
default (`allowed-tools` above deliberately omits Agent and Workflow).

Why: every subagent pays ~65–70k tokens of fixed context overhead (system prompt +
tool schemas) before doing any work, and subagents share no cache. A fanned-out run of
this pipeline (~50 micro-agents) costs 3–4M token-weight; the identical logic run
inline costs little more than its own output. The judging stages are exactly the kind
of small decisions that do not justify a fresh 67k context each.

Mitigate the loss of true generator blindness by ORDER: generate the full pool
(Step 2) before doing any judging (Steps 3–7), never revise earlier ideas while
generating later ones, and re-read CONSTRAINTS immediately before the kill pass.
Lenses still buy coverage even without process isolation.

Durability: after generation and after each filtering stage, append the current state
to a scratch file (pool, verdicts, survivors). Long runs may hit context
summarization; the scratch file is the recovery point.

## Step 0: Resolve the target plan.md — MANDATORY, never proceed on an ambiguous target

The skill must be directed at ONE specific plan.md before anything else runs. Resolution
ladder, in order:

1. **Explicit path argument** — if the user passed a `.md` path, use it. If they passed a
   repo directory, use `<repo>/docs/plan/plan.md` (the standard repo layout).
2. **Conversation context** — if one specific plan.md is already being discussed in this
   conversation, use it and state which one you chose.
3. **Current directory** — if cwd is inside a repo containing exactly one
   `docs/plan/plan.md` (fall back to `**/plan.md`), use it.
4. **Ambiguous or not found** — if multiple candidates exist, or none, STOP and use
   AskUserQuestion listing the discovered candidates (repo name + path) as options.
   Never guess between candidates and never run "untargeted" ideation against the home
   directory or the general environment.

Read the resolved plan.md in full. Derive from it:
- `REPO` = the repo root containing the plan (ledger, beads, and commits go here)
- `GOAL` = the plan's stated purpose, condensed to 2–3 sentences
- `CONSTRAINTS` = hard constraints from the plan, the repo's CLAUDE.md/README, plus any
  `--constraint` args. These become kill criteria later.

## Step 1: Ground (inline scout)

Scout the repo directly with Read/Glob/Grep — no agent. Produce a grounding digest:
what the app already does, architecture, existing features, open plan phases, open
beads (`bf ready` / `bf list` in REPO if it has `.beads/`), and anything in
`docs/notes/`. Also read the ledger `REPO/docs/notes/ideas-ledger.md` if it exists and
extract previously considered ideas as `PRIOR` (title + one-line + verdict).

The digest keeps generation from proposing what already exists and judging from
approving what a constraint forbids.

## Step 2: Generate — sequential lens passes, generation before judgment

Default lenses (override/extend via `--lens`):

1. invert-the-problem  2. adjacent-domain transplant  3. remove-a-constraint
4. 10x-cheaper/simpler version  5. power-user workflow  6. failure-mode/reliability-driven
7. novice-user/intuitiveness  8. "what would a competitor ship first"

Work through the lenses one at a time, fully adopting each lens's perspective for its
batch of `ceil(POOL / lenses)` ideas: short title + 1–2 sentence pitch naming mechanism
and value. Rules: nothing from the existing plan or PRIOR (a dead idea may be
resurrected only by stating why its kill objection no longer holds); no judging,
filtering, or self-censorship during generation — bad ideas get killed later, not here.
Append each lens batch to the scratch pool file as it's produced.

## Step 3: Cluster, then triage

- **Cluster**: group the full pool by underlying theme (6–14 named clusters). Merge
  exact/near duplicates, keeping the best phrasing.
- **Triage**: one harsh keep/cut pass with a one-clause reason each, down to
  ~2.5×KEEP survivors. Cut anything that already exists or violates a constraint.

## Step 4: Crossover

Scan survivor pairs for hybrids ("what if A's mechanism served B's goal?"). Add at
most a handful, and only where the hybrid is genuinely novel versus both parents.
Hybrids join the survivor pool as normal contenders.

## Step 5: Pairwise ranking — comparisons, never absolute scores

Rank survivors by explicit pairwise comparison, not 1–10 scoring: repeatedly pick the
winner of "A or B for GOAL under CONSTRAINTS, least complexity" with a one-clause
reason, using enough sampled pairings (~4 per idea) to sort the field. Top ~1.5×KEEP
advance. Enforce the cluster cap: **max 2 advancers per cluster** so the final set
spans distinct territories.

## Step 6: Adversarial kill pass

Re-read CONSTRAINTS, then attack each advancer in turn wearing the assassin hat — the
goal is to kill it: not worth its complexity budget, breaks a CONSTRAINT, mostly
duplicates something existing, or maintenance cost exceeds value. Verdict per idea:
KILL (with the fatal objection) or SURVIVES (with the strongest objection that still
stands). Steelman the kill before letting anything survive. All verdicts are recorded
in the ledger either way.

## Step 7: Completeness gap round

Review the surviving set's *shape* against GOAL: what region of idea-space is
unrepresented (reliability? novice UX? cost? observability?). If real gaps exist, run
ONE targeted generation batch for those gaps; entrants go through triage → kill pass
and may displace weaker survivors. Then select the final KEEP.

## Step 8: Deliver dossiers, write the ledger, offer beads

**Dossiers** — the final message presents each finalist as:
- one-line pitch, and why it won (cluster it beat, pairwise reasoning)
- complexity grade S/M/L and the concrete first implementation step
- the strongest surviving objection from the kill pass

Plus run stats: generated / deduped / triaged / killed counts and the ledger path.

**Ledger** — append a dated run section to `REPO/docs/notes/ideas-ledger.md` containing
ALL ideas (title, one-line, cluster, verdict + kill reason where applicable), finalists
marked. This is what future runs dedupe against. Commit it (with the plan.md edit below
if any) using the standard git identity; push only per the repo's usual rules.

**Selection** — AskUserQuestion (multiSelect) over the finalists: which to adopt. For
adopted ideas:
- create beads in REPO's workspace via `bf` (never `br`): `bf create` or `bf batch`
  with title + dossier body; if the repo has a genesis bead, add them as blockers of it
  (`dep_add_blocker`). Then `bf sync --flush-only` — beads are db-only until flushed.
- offer to append adopted ideas to the plan.md's roadmap/open-questions section so the
  plan stays the single complete picture.

## Key principles

- **One context, always** — the pipeline is reasoning passes, not an org chart; the
  token budget goes to ideas, not to re-shipping system prompts to micro-judges.
- **Generation before judgment** — the inline substitute for blindness: produce the
  whole pool before evaluating any of it; never self-censor mid-generation.
- **Lenses buy coverage** — forced perspectives, worked one at a time in full.
- **Pairwise beats scores** — "A or B" decisions are reliable; 1–10 ratings are not.
- **The kill pass encodes pragmatism** — an idea that can't survive a motivated
  assassin isn't worth the complexity burden.
- **Nothing is wasted** — losers and kill reasons live in the ledger; re-runs mine and
  dedupe against them.
- **Scale to the ask** — a quick "give me ideas" can shrink POOL to ~40 and skip
  crossover; "be exhaustive" scales POOL up (still inline).
