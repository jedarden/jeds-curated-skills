# Checklist 06 — Testing Strategy & Quality Gates

Tests specified in the plan are tests that actually get written.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **6.1 Testing Strategy Overview**
  At minimum: unit, integration, and acceptance testing approach stated.
  For systems with concurrency: stress / chaos testing included.

- [ ] **6.2 Tests Co-Located with Solutions**
  Each solution section has its own test specification, not consolidated
  in an appendix. Makes coverage gaps visible at review time.

- [ ] **6.3 Property-Based / Fuzz Tests**
  For any data processing, serialization, or protocol code: property-based
  tests specified. Not optional for this class of system.

- [ ] **6.4 Conformance Harness**
  For ports or replacements: tests that verify output matches the original
  system — not just internal unit correctness. File format round-trip tests.

- [ ] **6.5 Definition of Done / Quality Gates**
  Hard stop-ship criteria: "we do not ship if any of these fail."
  Separate from acceptance scenarios. Usually: lint + typecheck + test + bench.

- [ ] **6.6 All-Gates-Same-Commit Policy**
  Lint, type check, tests, and benchmarks must all pass on the same commit.
  No "tests pass but benchmarks broken" merges.

- [ ] **6.7 Evidence Bundle Requirement**
  For performance or correctness claims: the evidence required to substantiate
  the claim is specified in the plan. Not left to "we'll measure later."
