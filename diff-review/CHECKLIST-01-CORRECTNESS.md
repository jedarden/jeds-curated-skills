# Checklist 01 — Correctness

The primary lens. Flag only where the diff introduces or fails to fix a concrete defect.
Rate each: does the diff satisfy the criterion — PASS / CONCERN / FAIL.

- [ ] **1.1 Logic & Control Flow**
  Conditions, loops, and early returns do what the code intends. No inverted predicates,
  unreachable branches, or fall-through that skips required work.

- [ ] **1.2 Boundary & Off-by-One**
  Indexing, slicing, ranges, and loop bounds handle the first/last element and the empty case.
  No `<=` where `<` was meant (or vice versa); no length/index confusion.

- [ ] **1.3 Null / None / Optional Handling**
  Values that can be null/None/undefined/empty are checked before use. New code does not
  dereference a value the surrounding code treats as nullable.

- [ ] **1.4 Error & Exception Paths**
  Errors are propagated or handled — not swallowed. Returned error codes are checked. Cleanup
  still runs on the failure path. No bare catch that hides a real failure.

- [ ] **1.5 Resource Lifecycle**
  Files, sockets, locks, handles, transactions, and allocations are released on every path,
  including early returns and exceptions. No leak introduced by a new branch.

- [ ] **1.6 Concurrency & Races**
  Shared state mutated under the right lock; no check-then-act races, no data shared across
  threads/tasks without synchronization. Async values awaited before use.

- [ ] **1.7 API / Contract Usage**
  Called functions are used per their contract: argument order, units, ownership/borrowing,
  return-value semantics, idempotency. No deprecated-in-context or misused call.

- [ ] **1.8 Edge Cases at Boundaries**
  Empty input, single element, max size, zero/negative numbers, overflow, and timezone/encoding
  boundaries behave correctly for the changed code.

- [ ] **1.9 State & Invariants**
  Data structures stay internally consistent after the change. Invariants the rest of the code
  relies on are preserved across the new mutation.
