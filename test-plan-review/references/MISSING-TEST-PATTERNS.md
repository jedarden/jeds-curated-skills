# Commonly-Missed Test Categories

A catalog of test categories that suites routinely skip. Use it to name a specific gap
("you have no concurrency test for the cache") instead of a vague one ("more coverage").
Each entry: the blind spot, why it's missed, and a concrete example of the test to add.

---

## C1 — The Empty Case
**Blind spot:** Zero-element collections, empty strings, empty files, no-rows result sets.
**Why missed:** Examples and demos always use non-empty data.
**Example:** `sum([])` returns 0 not a crash; `render([])` shows the empty state, not a
NullPointer; `parse("")` returns a defined result, not undefined behavior.

## C2 — The Single-Element Case
**Blind spot:** Logic that works for 0 and for many but breaks at exactly 1 (pagination,
"and"-joining, median, neighbor comparisons).
**Why missed:** Tests jump from empty to a list of five.
**Example:** `format_list(["a"])` → `"a"`, not `"a and "` or `"a,"`.

## C3 — Boundary ±1
**Blind spot:** The value just under, exactly at, and just over a limit.
**Why missed:** Tests use a "typical" value far from any edge.
**Example:** max length 255 → test 254, 255, 256; assert the 256 case is rejected.

## C4 — Integer / Time Overflow
**Blind spot:** Values past `MAX_INT`, dates past 2038, durations that overflow ms.
**Why missed:** Real test data is small and recent.
**Example:** a counter at `i32::MAX` incremented once; a timestamp arithmetic near epoch wrap.

## C5 — Unicode / Encoding
**Blind spot:** Multi-byte chars, emoji, RTL text, combining marks, NUL bytes, BOM.
**Why missed:** ASCII fixtures only.
**Example:** truncating a string to N *bytes* splitting a multi-byte char; `len()` on emoji.

## C6 — The Error Path
**Blind spot:** What the function returns/raises when its precondition fails.
**Why missed:** Tests assert success; failure is "obvious."
**Example:** `withdraw(amount > balance)` raises `InsufficientFunds`, not a silent negative.

## C7 — Dependency-Down
**Blind spot:** The DB/API/queue/disk is unreachable or returns 5xx.
**Why missed:** Tests run against a healthy local stub.
**Example:** mock the HTTP client to raise `ConnectionError`; assert retry-then-surface, no hang.

## C8 — Timeout / Slow Dependency
**Blind spot:** A dependency that never responds.
**Why missed:** Local stubs are instant.
**Example:** stub that sleeps past the deadline; assert the timeout fires and is handled.

## C9 — Partial Failure Mid-Batch
**Blind spot:** Item K of N fails; what happens to 1..K-1 and K+1..N.
**Why missed:** Tests pass all-good or all-bad batches, never mixed.
**Example:** import 3 records where #2 is malformed; assert documented all-or-nothing vs skip.

## C10 — Idempotency / Double-Delivery
**Blind spot:** The same webhook / retry / message processed twice.
**Why missed:** Tests fire each operation once.
**Example:** POST the same payment twice with one idempotency key; assert one charge.

## C11 — Concurrency / Race
**Blind spot:** Two callers hitting shared state at once.
**Why missed:** Tests are single-threaded; races are nondeterministic and "rare."
**Example:** two threads incrementing a counter 1000× each; assert final value is 2000.

## C12 — Ordering Assumptions
**Blind spot:** Code assumes inputs arrive sorted / events in order.
**Why missed:** Fixtures happen to be pre-sorted.
**Example:** feed shuffled events; assert reordering or documented rejection.

## C13 — Resource Leak on Error
**Blind spot:** File/socket/lock opened, then an exception skips the close.
**Why missed:** Happy-path tests close cleanly; the error branch leaks silently.
**Example:** force an error after open; assert the handle is released (no leaked fd / held lock).

## C14 — Round-Trip Lossiness
**Blind spot:** serialize→deserialize or write→read that mangles edge values.
**Why missed:** Round-trip tested only with simple data.
**Example:** encode then decode a record with null, unicode, and a max-precision float; assert equality.

## C15 — Schema / Version Skew
**Blind spot:** New code reading data written by the old version.
**Why missed:** Tests only use data the current code wrote.
**Example:** load a fixture in the v1 format with new code; assert it migrates or reads cleanly.

## C16 — The Lying Mock
**Blind spot:** A mock that returns a shape the real dependency never returns.
**Why missed:** Mock is written to make the test pass, not to mirror reality.
**Example:** mock returns `{ok: true}` but the real API returns `{status: "ok"}`; the test is
green while production breaks. Pin mocks against a recorded real response.

## C17 — The Vacuous Assertion
**Blind spot:** `assertTrue(result is not None)`, `expect(fn).not.toThrow()`, bare snapshots.
**Why missed:** It's green, so it looks like coverage.
**Example:** replace the assertion with the actual expected value; if you can't, the test
proves nothing.

## C18 — Determinism Traps
**Blind spot:** `now()`, `random()`, set iteration order, locale, timezone, network.
**Why missed:** Passes locally today; flakes in CI or next year.
**Example:** a test that asserts "expires tomorrow" using real `now()` — inject a frozen clock.
