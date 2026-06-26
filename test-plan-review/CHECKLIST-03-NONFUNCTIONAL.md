# Checklist 03 — Non-Functional

Properties that hold across runs, threads, and time — not single-call correctness.
These gaps surface in production, never in a quick local run.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **3.1 Concurrency / Races**
  Code reachable from multiple threads/tasks/requests has tests that exercise it
  concurrently and assert no corruption, lost update, or deadlock. Single-threaded
  tests of concurrent code prove nothing.

- [ ] **3.2 Idempotency**
  Operations that claim to be safe-to-repeat (retries, webhooks, upserts, dedup) are
  tested by running them twice and asserting the second call is a no-op or identical.

- [ ] **3.3 Ordering**
  Where output order matters, it's asserted; where it must NOT matter, that's tested
  with shuffled input. Out-of-order delivery / processing is covered for event paths.

- [ ] **3.4 Resource Cleanup / Teardown**
  Files, sockets, temp dirs, locks, and handles opened by the code are asserted closed
  — including on the error path. Leaks tested, not just happy-path close.

- [ ] **3.5 Persistence Round-Trips**
  Write-then-read returns equal data; serialize-then-deserialize is lossless; the
  on-disk / on-wire format survives a round trip including edge values (null, unicode, max).

- [ ] **3.6 Migration / Schema Evolution**
  Where data formats or schemas version: old data is readable by new code, and
  migrations are tested forward (and backward if reversible) on representative fixtures.

- [ ] **3.7 Performance / Load Assertions (where relevant)**
  If the design states a latency or throughput budget, at least one test asserts it
  holds under representative load — not left to "we'll notice if it's slow."
