# Checklist 01 — Coverage

What the suite touches versus what the code can do. The gap is where bugs live.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **1.1 Every Public Entry Point Tested**
  Each exported function / public method / route / CLI subcommand has at least
  one test that calls it directly. Untested entry points are untested by definition.

- [ ] **1.2 Happy Path Per Behavior**
  The intended-use case for each behavior is exercised with realistic inputs and
  a concrete expected result — not just "does not throw."

- [ ] **1.3 Unhappy Paths**
  Invalid arguments, wrong types, out-of-range values, and rejected operations
  each have a test asserting the specific error or rejection — not just absence of success.

- [ ] **1.4 Boundary Values**
  At each numeric / size / length limit: the value just below, exactly at, and just
  above the boundary. Off-by-one bugs hide at the edges, not the middle.

- [ ] **1.5 Equivalence Classes**
  Inputs partitioned into classes (e.g. negative / zero / positive; ASCII / unicode /
  empty) with one representative test per class — not 50 near-identical happy cases.

- [ ] **1.6 Cardinality: Empty / One / Many / Max**
  Collections and iterables tested at zero elements, one element, many, and the
  documented maximum. The empty and single-element cases are the usual blind spots.

- [ ] **1.7 Branch / Decision Coverage of New Logic**
  Every `if` / `match` / `switch` arm and short-circuit in the logic under review has
  a test that forces it. Both sides of each conditional, not just the common one.

- [ ] **1.8 Default vs Explicit Configuration**
  Behavior tested both with defaults and with explicitly-overridden options/flags/env.
  Defaults drift; explicit paths are often never exercised.
