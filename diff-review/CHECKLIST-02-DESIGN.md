# Checklist 02 — Design & Cleanup

Secondary lens. Flag only clear, defensible issues — not taste. Rate each: does the diff
satisfy the criterion — PASS / CONCERN / FAIL.

- [ ] **2.1 Duplication / Missed Reuse**
  New code does not reimplement logic that already exists nearby. An existing helper, constant,
  or abstraction should have been reused.

- [ ] **2.2 Leaky Abstraction**
  Implementation details do not bleed across a boundary. Callers are not forced to know internals
  the interface was meant to hide.

- [ ] **2.3 Unnecessary Complexity**
  The change is no more complex than the problem requires. No speculative generality, redundant
  indirection, or convoluted control flow where a straight line would do.

- [ ] **2.4 Naming**
  Names describe what the thing is/does and match local conventions. No misleading name (a
  `get` that mutates, a `count` that returns a list).

- [ ] **2.5 Dead Code**
  No unreachable code, unused variable/import/parameter, or commented-out block introduced by
  the diff. Removed code leaves no dangling reference.

- [ ] **2.6 Wrong Layer / Altitude**
  Logic sits at the appropriate layer — business rules not buried in a formatter, I/O not done
  inside a pure helper, config not hardcoded in a leaf function.

- [ ] **2.7 Backward-Compatibility Breaks**
  Changes to public signatures, serialized formats, on-disk schemas, env vars, or wire protocols
  are either compatible or clearly intentional with callers updated.

- [ ] **2.8 Consistency With Surroundings**
  The change follows the patterns, idioms, and conventions already established in the file/module
  rather than introducing a one-off style.
