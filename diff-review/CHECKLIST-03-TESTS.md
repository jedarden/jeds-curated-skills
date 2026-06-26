# Checklist 03 — Tests

Assess whether the diff's behavior changes are adequately tested. Rate each: does the diff
satisfy the criterion — PASS / CONCERN / FAIL. Only flag clear gaps in behavior that the diff
itself introduces.

- [ ] **3.1 Changed Behavior Is Covered**
  New or modified behavior has at least one test that would fail without the production change.
  A bug fix has a regression test reproducing the original bug.

- [ ] **3.2 New Branches Are Exercised**
  Branches introduced by the diff (new conditionals, error handlers, edge cases) are each hit by
  a test, not just the happy path.

- [ ] **3.3 Assertions Are Meaningful**
  Tests assert on real outcomes, not tautologies. No `assert true`, no asserting a mock was
  called without checking the effect, no test that passes regardless of the code.

- [ ] **3.4 Failure Paths Tested**
  Error and exception paths added by the diff have a test that drives them — invalid input,
  downstream failure, timeout — and asserts the correct error behavior.

- [ ] **3.5 Test Isolation & Determinism**
  New tests do not depend on wall-clock time, network, ordering, or shared mutable state in a way
  that makes them flaky or order-dependent.

- [ ] **3.6 No Weakened Coverage**
  The diff does not delete, skip, or loosen an existing test to make a change pass without
  justification.
