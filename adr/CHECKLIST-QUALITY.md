# Checklist — ADR Quality

A weak ADR records a choice but hides the reasoning, so future readers cannot tell whether it still
holds. Rate each item: PRESENT / PARTIAL / MISSING

- [ ] **1.1 Title is a Decision, Not a Topic**
  The title states the choice made ("Use cursor-based pagination"), not the subject area
  ("Pagination"). A reader knows the verdict from the title alone.

- [ ] **1.2 Status Present and Lifecycle-Correct**
  Exactly one of Proposed / Accepted / Deprecated / Superseded. Superseded records point to
  their replacement; deprecated records say what to do instead.

- [ ] **1.3 Date Present and Meaningful**
  A date reflecting when the status last changed — so staleness is visible.

- [ ] **1.4 Context States the Forces, Not Just the Choice**
  The constraints, requirements, and tensions that made the decision necessary are described.
  A reader who disagrees with the decision still agrees the situation is described accurately.
  A context that only restates the decision is PARTIAL.

- [ ] **1.5 Decision is Specific and Actionable**
  Stated in active voice ("We will …"), naming the concrete mechanism/library/pattern. Someone
  could act on it without re-deriving the intent. Vague directional statements are PARTIAL.

- [ ] **1.6 At Least Two Real Alternatives Genuinely Weighed**
  Two or more alternatives, each steel-manned with honest pros. An alternative listed only to be
  dismissed in one line (no real pros, obviously inferior) is a STRAWMAN — flag it; that item is
  PARTIAL at best.

- [ ] **1.7 Each Alternative Has a Specific "Why Not"**
  Each rejected option ties its rejection to a concrete force from Context, not a generic
  "too complex." Different alternatives should fail for different reasons.

- [ ] **1.8 Consequences Include the Negatives**
  What becomes harder, slower, or foreclosed is stated explicitly — not only the benefits. An
  all-positive consequences section is MISSING this item, however long it is.

- [ ] **1.9 Follow-On Work Identified**
  Migrations, new tasks, or downstream decisions this choice triggers are named.

- [ ] **1.10 Reversibility / Blast Radius Noted**
  Whether this is a one-way or two-way door, what reversal would cost, and what would trigger it.

- [ ] **1.11 Supersession Links Maintained**
  If this ADR replaces another, it links the old one AND the old one's status points back here.
  Links are reciprocal, never one-directional. (PRESENT by default when no supersession applies.)

- [ ] **1.12 Scoped to One Decision**
  The record covers a single decision. Multiple unrelated decisions bundled together is PARTIAL —
  they should be split.
