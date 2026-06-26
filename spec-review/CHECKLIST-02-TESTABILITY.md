# Checklist 02 — Testability & Measurable Acceptance

A requirement you cannot test is a wish. If "done" is undefined, the build never ends.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **2.1 Observable Acceptance Condition per Requirement**
  Each functional requirement states an observable outcome a tester (human or automated)
  can confirm without reading the author's mind.

- [ ] **2.2 Measurable Success Metrics**
  Non-functional goals carry numbers: latency targets, throughput, error budgets, accuracy.
  "Performant" / "scalable" / "reliable" alone is MISSING.

- [ ] **2.3 No "Works Well" Requirements**
  No requirement whose acceptance is subjective ("works well", "behaves correctly",
  "handles X gracefully") without a defined yardstick for the judgment.

- [ ] **2.4 Given/When/Then or Equivalent**
  Key behaviors are expressed as precondition → trigger → expected result, or an
  equivalently structured acceptance scenario, not prose hand-waving.

- [ ] **2.5 Quantified Thresholds and Boundaries**
  Limits ("up to N items", "within T seconds", "at least P percent") are explicit numbers,
  and boundary behavior at the limit is specified.

- [ ] **2.6 Verifiable Negative Requirements**
  "Must not" requirements state how the prohibition is checked, not just that it exists.

- [ ] **2.7 Acceptance Owner / Sign-off**
  It is clear who confirms each requirement is met and what evidence satisfies them.
