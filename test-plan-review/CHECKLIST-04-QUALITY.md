# Checklist 04 — Test Quality

A passing test is only useful if it would FAIL when the code breaks. These checks
catch tests that lie — green for the wrong reason.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **4.1 Determinism**
  No dependence on wall-clock time, `now()`, random seeds, network availability, or
  timezone/locale. Clocks and randomness are injected/frozen. Flaky = useless.

- [ ] **4.2 Test Isolation**
  No shared mutable state between tests; order-independent; no reliance on a prior
  test having run. Each test sets up and tears down its own world.

- [ ] **4.3 Meaningful Assertions**
  Tests assert specific expected values, not `assertTrue(true)`, not "no exception,"
  not bare not-null. Snapshot-only tests that nobody reviews count as PARTIAL at best.

- [ ] **4.4 Clear Arrange / Act / Assert**
  Each test has a distinct setup, a single action under test, and focused assertions.
  Not a 200-line method exercising ten behaviors where one failure masks the rest.

- [ ] **4.5 Fixtures & Teardown**
  Setup is shared via fixtures, not copy-pasted; teardown reliably runs (even on
  failure) so tests don't pollute each other or the environment.

- [ ] **4.6 No Over-Mocking**
  Mocks stand in for genuinely external/slow/nondeterministic boundaries — not for the
  unit under test. Over-mocked tests assert the mock was called, not that behavior is
  correct, and pass even when the real integration is broken.

- [ ] **4.7 Negative Tests Can Actually Fail**
  Spot-check that error/negative tests fail when the guard is removed. A test that
  passes whether or not the bug exists is decoration, not coverage.
