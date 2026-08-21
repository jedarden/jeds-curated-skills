---
name: plan-review
version: 2.0.0
description: >-
  Pre-flight review of a software plan that hunts for the decisions an implementer will be
  forced to make that the plan has not made — and proposes each one — so the plan itself is the
  decision record and no ADRs are needed mid-build. Runs inline in a single context (no
  subagents). Produces a verdict (NOT READY / READY AFTER DECISIONS / READY), a decision ledger
  with a proposed resolution per open fork, an implementer dry-run, a reality check against the
  real repo and cluster, hard safety caps, and a compact structural sweep. `--lock` writes
  accepted decisions into the plan where an implementer will actually read them. Use before
  implementation begins, before decomposing a plan into beads, or whenever a project keeps
  spawning ADRs after the plan was "done".
argument-hint: "[path/to/plan.md] [--fast] [--lock DN-1,DN-3 | --lock all]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Plan Review

**Thesis.** In-flight pivots are not caused by missing section headers. They are caused by
*unmade decisions* meeting reality: an implementer (increasingly an autonomous worker holding
one bead, unable to ask) reaches a fork the plan never chose, guesses, and the guess is later
ratified or reversed as an ADR. Every post-hoc ADR is a decision the plan should have made.

So this review does not grade a plan by how many of 83 headers it has. It asks one question,
five ways: **what will the implementer have to decide that this document has not decided?**
Then it proposes the decision — with rationale, the rejected alternative, the test that
enforces it, and the signal that would reopen it — so the human's job shrinks to saying "yes".

**Run everything inline.** Do not spawn subagents for judgement; the plan must stay in one
context so that the dry run, the ledger, and the proposed decisions are consistent with each
other. Plans up to ~6k lines fit; for larger ones read in section-sized chunks, never skim.

## Step 0 — Resolve the plan and the mode

- Path argument → use it. Otherwise exactly one `docs/plan/plan.md` under cwd → use it.
  Otherwise scan `**/plan.md`, `**/PLAN*.md`, `**/design.md`, `**/ARCHITECTURE.md`; if several,
  AskUserQuestion once.
- `--fast` → follow `runbooks/FAST-PATH.md` (caps + forks only, ~5 minutes) and stop.
- `--lock …` → a memo from a previous run must exist next to the plan (Step 6 names where);
  follow `runbooks/LOCK.md` and stop. If none exists, run the full review first.
- Read the **entire** plan. Note its git state: `git -C <repo> log -1 --format='%h %cs' -- <plan>`
  and whether implementation code exists yet (`ls` the repo; a plan with code is a *stale
  plan* and Lens C gets heavier).
- Load the **house rules**: every `CLAUDE.md` / `AGENTS.md` from the plan's directory up to
  `$HOME`. Hard prohibitions in those files are forks the plan must already comply with
  (Cap C6). Do not hardcode environment rules in this skill — read them.

## Step 1 — Classify the plan (changes which lenses weigh most)

| Type | Tell | Extra weight |
|---|---|---|
| Greenfield | nothing exists yet | first slice, acceptance, interface shape |
| Port | reimplementing an existing system | parity, conformance oracle, source metrics |
| Improvement | evolving a running system | reality check, regression guard, what-we're-NOT-changing |
| Integration | wiring two existing systems | ownership boundaries, failure isolation, contract versioning |
| Migration / Cutover | moving data, users, or traffic | backup + rollback + trigger, idempotency, shadow/canary |
| Spike | produces a *decision*, not a system | question, metric, environment, decision-by gate, default |

A Spike is judged almost entirely by `S.*` in the sweep; most structural items are N/A for it.

## Step 2 — Mechanical pre-pass (locators, never verdicts)

```bash
~/.claude/skills/plan-review/scripts/find-forks.sh <plan>     # DEFER / HEDGE / SHADOW / UNQUANTIFIED hits with line numbers
~/.claude/skills/plan-review/scripts/scan-headers.sh <plan>   # section map with line numbers
```

These tell you *where to look*. A clean scan proves nothing — a plan can say "SQLite" with
total confidence and still never decide what happens when the disk fills. Lenses A–E decide.

## Step 3 — Lens A: the Decision Ledger (the ADR-eliminator)

Read `references/DECISION-LEDGER.md` — a catalog of the ~50 canonical forks (storage, IDs,
staleness, concurrency, error model, config surface, exposure, rollout, …), each with the
incident it causes when left open. Build the ledger:

1. **Extract** every fork the plan will hit: walk the catalog domain by domain and ask "does
   this system have this fork?"; add forks specific to this domain that the catalog lacks;
   add every `find-forks` hit.
2. **Classify** each fork into exactly one state:
   - **LOCKED** — choice + why + rejected alternative + enforcement (test/gate/invariant/lint)
     + revisit trigger. Nothing to do.
   - **ASSERTED** — a choice is stated, no rationale or alternative. Fine for low-stakes forks;
     a finding when the fork is a churn-magnet (high reversal cost).
   - **RECOMMENDED** — still open, but the plan names a recommended default and what would
     change it. Acceptable. Endorse it (→ propose locking) or dispute it.
   - **SPIKED** — cannot be decided from the armchair; the plan names a time-boxed experiment
     with metric, environment, decision-by gate, and the default if inconclusive. Acceptable.
   - **DEFERRED** — "TBD / later / likely / e.g. / or similar / candidate" with no owner, gate,
     or default. **Finding.**
   - **UNNOTICED** — the fork exists and the plan never mentions it. **Finding** — the expensive
     kind, found by the catalog and by Lens B, never by grep.
   - **SHADOW** — decided somewhere an implementer will not read it: an ADR appended after the
     Open Questions, a "decided 2026-xx-xx" amendment buried in a paragraph, a struck-through
     question, a bead, a commit, a memory note. **Finding** — fold it into its home section.
3. **Rate stakes** by reversal cost: *high* (language/runtime, storage engine, data format,
   ID scheme, public interface shape, deployment unit, auth model, source of truth), *medium*
   (library, config format, retry/timeout policy, schema field), *low* (naming, log wording).
4. **Rate proximity**: which phase first needs the answer. A high-stakes DEFERRED/UNNOTICED
   fork needed by the first two phases is Cap C4.
5. **Propose the decision** for every finding, grounded in *this* plan's constraints and the
   house rules — never boilerplate. Use the compact form in `references/EXEMPLARS.md`:
   **Decision / Because / Rejected / Enforced by / Revisit if.** If the honest answer is "it
   must be measured", propose a **spike** (question, metric, environment, decide-by gate,
   default if inconclusive) — never `[FILL IN]`, never "benchmark later".

Findings become `DN-n` entries (Decision Needed), ordered by stakes × proximity.

## Step 4 — Lens B: the implementer dry run (the pivot simulator)

Pretend to be the worker who claims the first bead of Phase 0 (or 1) and cannot ask anyone
anything. Narrate, concretely: the first five files or commands you would create, in order.
At each one write down (a) what you had to decide that the plan didn't, (b) what you had to
look up outside the document. Repeat for the single riskiest later phase. Every question
becomes a ledger entry (UNNOTICED or DEFERRED) or a reality-check claim (Lens C).

Then the **fleet test**: if this phase were cut into single-task beads, would any bead require
a design call? Those are either decisions to lock now or explicit human-gate beads the plan
must name. A plan that passes the fleet test needs no ADRs.

## Step 5 — Lens C: reality and consistency

- **Load-bearing claims.** List up to eight claims the plan makes about things that already
  exist (a trait, a route, a table, a library capability, a cluster's headroom, a CI template,
  an OpenBao path). Verify the cheap ones with read-only commands only (`grep`, `ls`,
  `kubectl get`, a `curl -sI`). Mark VERIFIED / FALSE / UNVERIFIABLE-FROM-HERE. A FALSE
  load-bearing claim is Cap C5.
- **Stale plan** (code exists): diff plan ↔ code on component names, schema, and phase
  completion; anything the code decided that the plan didn't is a SHADOW entry.
- **Contradictions.** Non-goal vs. phase deliverable; data model vs. API; invariant vs. edge
  case resolution; two sections giving two values for one knob; a struck-through question
  whose resolution never reached the body. Quote both sides with line numbers.
- **Freshness.** Date stamp, revision history, "as of" markers older than the code.

## Step 6 — Lens D: safety caps (any one tripped ⇒ NOT READY)

| Cap | Tripped when |
|---|---|
| C1 | The central outcome has no observable pass/fail criterion — success is indistinguishable from failure. |
| C2 | A destructive or irreversible step (migration, deletion, cutover, key rotation) has no backup, no rollback mechanism, or no rollback trigger. |
| C3 | There is no bounded first slice — no phase that can be demonstrated end-to-end before the rest is built. |
| C4 | A high-stakes DEFERRED / UNNOTICED fork sits on the critical path of the first two phases. |
| C5 | A load-bearing claim about existing reality is false. |
| C6 | The plan violates a hard rule in the governing `CLAUDE.md` / `AGENTS.md` — it will be rejected at PR or sync time. |
| C7 | The system touches secrets or untrusted input and states no handling policy at all. |

There are no percentages. Percentages reward length; caps reward safety.

## Step 7 — Lens E: structural sweep (the safety net, demoted)

Read `references/STRUCTURAL-SWEEP.md` once. Rate each applicable item PRESENT / PARTIAL /
MISSING / **N/A (reason)**. Applicability is a judgement — a 200-line CLI plan is not MISSING
a per-threat security matrix, it is N/A. Only applicable MISSING/PARTIAL items surface in the
memo body, as one compact list; the full table goes in the appendix.

## Step 8 — Verdict and memo

Verdict, in this order of precedence:
- **NOT READY** — any cap tripped. Lead with the cap.
- **READY AFTER DECISIONS (n)** — no caps; *n* DN entries await a human's yes/no. The expected
  and best outcome: "answer these n questions and it is ready." Each DN already carries the
  proposed answer.
- **READY** — no caps, no DN on any phase's critical path; what remains is cosmetic.

Write the memo with `REPORT-TEMPLATE.md` — verdict and one plain paragraph first, then
**Decide these now**, the dry run, reality, caps, the compact sweep, strengths, appendices.
Every finding anchors to `file:line`. Save it so it outlives the transcript:

- plan at `docs/plan/plan.md` → `docs/notes/plan-review-<YYYY-MM-DD>.md`
- anywhere else → `<plan-dir>/<plan-basename>-review-<YYYY-MM-DD>.md`

Then print the verdict line, the DN list (one line each), and the memo path. Do **not** edit
the plan in this pass — decisions belong to the human; your job was to make saying "yes" cheap.
Close with exactly one suggested next action: `/plan-review --lock all` (or a subset) if the
proposals are sound, or the single cap to fix if NOT READY.

## Step 9 — `--lock` (separate invocation)

`runbooks/LOCK.md`. Accepted DNs are written *where an implementer will read them* in the
compact Decision form, Open Questions are reconciled, SHADOW decisions are folded into place,
remaining DNs become `DECISION NEEDED` callouts with a recommended default and a resolve-by
gate. Never a 60-line ADR appended at the end; never a `[FILL IN]`.

## Other runbooks

- `runbooks/FAST-PATH.md` — five-minute go/no-go: caps + forks, no sweep.
- `runbooks/MULTI-PLAN-COMPARISON.md` — two plans for one system: diff the ledgers, not the headers.

## Calibration

`references/EXEMPLARS.md` shows what a locked decision, a well-parked open question, a spike,
and an acceptance scenario look like — and the anti-patterns this skill exists to catch (the
appended ADR, the `[FILL IN]`, the "likely axum", the "candidate default" that never locked).
`SELF-TEST.md` has fixtures with expected results.
