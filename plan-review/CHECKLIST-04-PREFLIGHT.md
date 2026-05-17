# Checklist 04 — Pre-Flight Safety

These are the sections that separate plans built cleanly from plans that stall.
This is the most important category. Rate each: PRESENT / PARTIAL / MISSING

- [ ] **4.1 Edge Case Catalog**
  Explicit numbered catalog of known edge cases. Each entry has:
  name, description, and resolution strategy.
  Not inline mentions — a dedicated section. Minimum 5 entries for non-trivial systems.

- [ ] **4.2 Failure Modes & Resilience**
  Taxonomy of failure types (network, disk, input, dependency, internal logic)
  with recovery strategy per type. Each failure mode has a specified test.

- [ ] **4.3 Anti-Patterns Catalog**
  First-class section on what NOT to do and why.
  Prevents "seemed reasonable at the time" decisions during implementation.

- [ ] **4.4 Error Taxonomy / Error Code Catalog**
  Structured error codes grouped by type with recommended recovery actions.
  Errors designed upfront = consistent UX and debuggability.

- [ ] **4.5 Rollback / State Capture Plan**
  For any destructive or irreversible operation:
  - State captured before executing
  - Artifact named
  - Rollback command specified
  Defined at design time, not after something goes wrong.

- [ ] **4.6 Graceful Degradation / Offline Mode**
  Every network-dependent feature explicitly specifies:
  - What works offline
  - What doesn't
  - What the user sees in degraded mode

- [ ] **4.7 Invariants**
  Named, testable system invariants that must always hold.
  Treated as CI-enforced properties, not prose assertions.

- [ ] **4.8 Safe Defaults / Fail-Safe**
  Risky or destructive operations require explicit opt-in (e.g., `--force`).
  Default behavior is always the safe choice.

- [ ] **4.9 Proof Obligations / Regret Ledger**
  For ambitious claims or high-stakes decisions: a list of what would have to be true
  for the decision to be correct, and what evidence would invalidate it.
  Prevents "we were too confident" pivots.
