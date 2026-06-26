# ADR Template

Copy this structure for every new ADR. File name: `NNNN-short-kebab-title.md` (4-digit zero-padded
sequence). Keep it one decision per record. Be specific; an ADR that could apply to any project is
worthless.

---

# NNNN. <Title — the decision, not the topic>

> Good: "Use cursor-based pagination for the public API"
> Bad: "Pagination" (a topic, not a decision)

- **Status:** Proposed | Accepted | Deprecated | Superseded by [NNNN](NNNN-other.md)
- **Date:** YYYY-MM-DD (date the status last changed)
- **Deciders:** <who made or ratified this> *(optional)*
- **Supersedes:** [NNNN](NNNN-old.md) *(omit unless this replaces an earlier ADR)*

## Context

The forces at play — not the choice. State the constraints, requirements, and pressures that make
this decision necessary and non-obvious:

- The problem being solved and why it needs deciding now.
- The constraints that bound the solution space (scale, latency, team size, deadlines, existing
  stack, compliance).
- The forces in tension (e.g. simplicity vs. flexibility, consistency vs. availability).

A reader who disagrees with the decision should still agree this is an accurate description of the
situation.

## Decision

State the choice in active voice, present/future tense: **"We will …"**

Be specific and actionable — name the mechanism, library, pattern, or boundary chosen. A reader
should be able to act on this sentence without further interpretation.

## Considered Alternatives

At least two real alternatives, each steel-manned — argue each as its strongest advocate would,
then say honestly why it lost. No strawmen.

### Alternative A — <name>
- **Pros:** …
- **Cons:** …
- **Why not:** the specific force from Context that ruled it out.

### Alternative B — <name>
- **Pros:** …
- **Cons:** …
- **Why not:** …

*(Add more as warranted. The chosen option may also appear here for contrast.)*

## Consequences

Honest results of the decision — positive **and** negative.

- **Positive:** what gets easier, faster, safer, or cheaper.
- **Negative:** what gets harder, slower, or more constrained. What capability is now foreclosed.
  Every real decision has a cost — if this list is empty, the analysis is incomplete.
- **Follow-on work:** new tasks, migrations, or future decisions this triggers.

## Reversibility / Cost to Change

- **Blast radius:** what breaks or must change if this is later reversed (one component vs. a
  cross-cutting rewrite).
- **Type:** one-way door (expensive, near-irreversible) vs. two-way door (cheap to revisit).
- **Reversal trigger:** the conditions or signals that would justify revisiting this decision.
