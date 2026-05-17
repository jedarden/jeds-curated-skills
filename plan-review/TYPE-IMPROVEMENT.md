# Type-Specific Checks — Improvement Plans

An improvement plan evolves an existing system.
These checks are in addition to the universal checklist.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **I.1 Gap Inventory**
  Catalog of what is broken or missing in the current system, written before
  any solutions are proposed. Prevents "solution in search of a problem."

- [ ] **I.2 "What We're NOT Changing" Section**
  Explicit statement of what stays the same. Prevents scope creep during
  implementation and gives reviewers a clear boundary to hold.

- [ ] **I.3 Incident Class Named**
  The real failure, incident, or pain that prompted this improvement is named.
  Prevents solving symptoms instead of root cause.

- [ ] **I.4 Existing Data Format Compatibility**
  All schema or format changes are explicitly called out.
  Format compatibility verified against existing data before any migration runs.

- [ ] **I.5 Rollback Criteria Defined Before Rollout**
  Specific conditions under which the improvement is rolled back, defined in
  the plan — not written after discovering a regression in production.

- [ ] **I.6 Behavioral Regression Tests**
  Tests that verify existing behavior is preserved, written before the
  improvement is implemented. Catches unintended regressions early.
