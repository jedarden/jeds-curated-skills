# Checklist 02 — Failure Handling

Code is judged by how it fails, not how it succeeds. Most suites only prove the
sunny day. Rate each: PRESENT / PARTIAL / MISSING

- [ ] **2.1 Error / Exception Paths Asserted**
  Every documented error case has a test asserting the *specific* error type, code,
  or message — not a blanket "expect it to throw something."

- [ ] **2.2 Failure Injection**
  Failures are deliberately induced (mocked errors, fault hooks, killed dependencies)
  to drive code down its recovery branches. Not relying on real failures to happen.

- [ ] **2.3 Dependency-Down**
  Behavior when a downstream dependency (DB, API, queue, filesystem) is unreachable,
  returns 5xx, or rejects the connection. Each external call has a failure test.

- [ ] **2.4 Timeouts**
  Slow / hanging dependencies tested — the code's timeout fires and is handled, and
  the test itself doesn't hang waiting. Deadline behavior is asserted, not assumed.

- [ ] **2.5 Retries & Backoff**
  Retry logic tested: succeeds-after-N-failures, exhausts-retries, and that retries
  don't fire on non-retryable errors. Retry counts and backoff actually verified.

- [ ] **2.6 Partial Failure**
  Multi-step / batch operations tested when step K fails: is state consistent, is the
  batch rolled back or partially committed as documented, are completed items reported.

- [ ] **2.7 Malformed / Hostile Input**
  Truncated, oversized, wrong-encoding, injection-shaped, and schema-violating inputs
  are rejected cleanly without crash, hang, or corruption.

- [ ] **2.8 Resource Exhaustion**
  Out-of-memory, disk-full, connection-pool-empty, and rate-limit conditions degrade
  gracefully where the design claims they do. At least the claimed limits are tested.
