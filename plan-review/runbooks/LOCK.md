# Runbook: `--lock` — write accepted decisions into the plan

Invoked as `/plan-review <plan> --lock DN-1,DN-3` or `--lock all`, after a memo exists. This is
the only mode that edits the plan. It replaces the old "draft the missing sections" step: the
goal is a plan that *decides*, not a plan that is longer.

## 0. Preconditions

- The memo from the most recent run exists at the path SKILL.md Step 8 names. If not, run the
  full review first — never lock from memory.
- Re-read the plan in full. Someone may have edited it since the memo.
- If the repo has uncommitted changes to the plan, stop and say so; do not stack edits on
  someone's in-flight work.
- Resolve which DNs are in scope: the explicit list, or every DN for `all`. For `all`, the DNs
  whose proposed decision the memo marked as *needs a human value* (a number you could not
  derive, a stakeholder preference) are **not** auto-locked — they become callouts (§3).

## 1. For each accepted DN — write the decision where it lives

1. **Find the home.** The section an implementer reads when they hit this fork: the data
   model for schema and IDs, Architecture / Components for engines and libraries,
   Infrastructure / Operations for exposure, storage class, CI, and rollout, the interface
   section for surface shape and error model. Never the end of the file. Never a new
   "Decisions" appendix.
2. **Write it in Form 1** (`references/EXEMPLARS.md`): bold headline stating the choice,
   then **Because / Rejected / Enforced by / Revisit if**. Five to eight lines. In the plan's
   own voice and heading style. Reference the plan's real components and sections.
3. **If the plan already asserts the choice** (ASSERTED → lock), keep the author's sentence
   and add the four lines under it — do not rewrite their prose.
4. **If the decision changes something said elsewhere**, fix every occurrence. One value per
   knob per document. `grep` for the old value before you finish.
5. **If the proposal was a spike**, write Form 4 at the home section and add the spike to the
   phase that must run it, with its decide-by gate in that phase's completion criteria.
6. **Add the enforcement** to the place enforcement lives: the test list of the relevant
   phase, the invariants section, or the quality gates — whichever the plan has. A decision
   with no test is an opinion.

## 2. Reconcile Open Questions

- A question answered by a locked DN is removed from Open Questions and replaced with one
  line: `~~<question>~~ — resolved <date>, see §<home section>.` Keep the strike-through
  for one revision so readers see it moved; it is not a SHADOW decision because the body now
  carries the answer.
- Never leave a "decided …" paragraph *inside* Open Questions as the only copy of a decision.

## 3. Fold SHADOW decisions into place

- **Appended ADRs** (an `## ADR-nnn` after Open Questions): write the decision in Form 1 at
  its home section, ending with "(full record: ADR-nnn below)". Leave the ADR body where it
  is — it is history and may be cited by beads or commits. Do not delete content.
- **Inline amendments** ("decided 2026-07-20" buried in a paragraph): move the decision to its
  home in Form 1; shrink the amendment to a one-line pointer.
- **Decided in code or beads but not in the plan**: write it into the plan as ASSERTED →
  LOCKED with `Because` derived from the code's own comments or commit message; cite the
  commit.

## 4. DNs not locked — leave a callout, not a hole

For every DN the human has not accepted (or that needs a human value), insert Form 5 at the
home section:

```markdown
> **DECISION NEEDED (DN-n): <fork>.** <what the plan currently says, one line>
> **Recommended:** <choice> — <one-line because>. **Resolve by:** <phase / gate>.
> To adopt: `/plan-review --lock DN-n`.
```

and add a matching entry to Open Questions in Form 3 (recommended default + answer plan +
resolve-by + impact if wrong). A reader now finds the fork at the place it bites *and* in
the index of open items, and can close it with one word.

## 5. Hygiene

- Bump the date stamp / revision history: `<date> — locked DN-1, DN-3; callouts for DN-2.`
- **Never write `[FILL IN …]`, `TBD`, or "benchmark later".** An unknown number is a spike
  (Form 4) or an Open Question with a default (Form 3).
- Keep heading levels and numbering consistent with the file. If the plan uses `AS-nn`,
  `EC-nn`, `INV-nn` identifiers, continue the series; do not start a new scheme.
- Do not introduce scope. If a locked decision reveals a missing feature, that is a new Open
  Question with a recommended default, not a new phase.
- Re-run `scripts/find-forks.sh <plan>`; the DEFER count must not have risen.

## 6. Report

Print a diff summary, not the diff:

```
Locked 3 decisions into <plan>:
  DN-1 storage engine          → §6.1 Components        (+7 lines)
  DN-3 front-page TTL          → §7 Data Model          (+8 lines, 1 value corrected at :28)
  DN-4 registry                → §13.1 Deployment       (+6 lines)
Callouts left for the human:
  DN-2 backup interval         → §13.1 + Open Questions  (recommended 15 min)
Open Questions: 2 resolved (struck, pointer added), 1 added.
SHADOW folded: ADR-001 summarised at §6 Architecture; body retained.
find-forks: DEFER 4 → 1, SHADOW 2 → 0.
Working tree: <plan> modified, not committed.
```

Committing is the caller's decision; say plainly that the plan is modified and uncommitted.
The one-line next action is `/plan-review <plan>` again if anything was left as a callout, or
`/plan-to-bead` if the ledger is clean.
