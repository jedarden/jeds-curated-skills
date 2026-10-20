# Examples — GOOD vs WEAK

Calibration snippets for the drafter. The difference is almost always specificity plus a named
rationale. WEAK could apply to any project; GOOD could only describe this one. The running example
is a generic file-sync CLI called `syncd` and a generic web service called `linkapi`.

---

## Non-Goal

**WEAK**
```markdown
- No real-time sync.
```
States *what* but not *why*; a reader cannot tell if it was a decision or an oversight.

**GOOD**
```markdown
- **No real-time sync.** `syncd` reconciles on an explicit `sync` invocation or a timer, not on
  filesystem events. Watching the tree would require a per-OS file-watch layer and an in-memory
  index that survives crashes — a class of bugs (missed events, watch exhaustion) that buys us
  nothing for a tool whose users sync on a schedule. The right time to revisit is if a user
  demonstrates a sub-minute freshness need.
```
Names the excluded thing, the cost of including it, and the condition that would reopen it.

---

## Acceptance Scenario

**WEAK**
```markdown
The tool should sync files correctly and handle errors gracefully.
```
Not testable. "Correctly" and "gracefully" have no pass/fail edge.

**GOOD**
```markdown
### Scenario 2: Remote Unreachable Mid-Sync
- **Setup:** 500 files queued; network drops after 200 are uploaded.
- **Action:** User runs `syncd push`.
- **Expected:** Upload halts, the 200 committed files stay committed, `syncd` exits 75 and prints
  "Network lost after 200/500. Re-run `syncd push` to resume; no files were corrupted."
- **Pass:** exit code 75; the 200 uploaded files match source checksums; re-running resumes at
  file 201; zero partial/corrupt files on the remote.
- **Fail:** any partially written remote file; exit 0 despite incomplete sync; resume re-uploads
  already-committed files.
```

---

## Architecture / Technology Decision

**WEAK**
```markdown
We will use a database to store state.
```
No choice made, no reason, nothing to disagree with or test.

**GOOD**
```markdown
**State store: SQLite (single-writer), not a flat JSON file.**
`linkapi` records link metadata and a per-link fetch history. A JSON file would require rewriting
the whole document on every update and offers no crash-safe partial write. SQLite gives atomic
writes, indexed lookups by URL, and a WAL we already understand. We accept its single-writer
limit because §6.3 fixes the writer count at one (the API process); read replicas are a non-goal.
```

---

## Edge Case

**WEAK**
```markdown
Handle the case where the file is missing.
```
Restates the problem; provides no behavior to implement or verify.

**GOOD**
```markdown
**EC-04: Source path disappears between scan and upload.**
Resolution: the uploader re-stat()s each file immediately before reading it. If the file is gone,
skip it, record it in the run report under "vanished", and continue — do NOT abort the batch.
Exit code stays 0 if every other file succeeded; the report's `vanished` count is non-zero so
callers can detect it. A vanished file is never an error because concurrent edits are expected.
```

---

## First Slice (Phase 0)

**WEAK**
```markdown
| 0 — Consolidated baseline | This plan, source provenance, requirements, conflict dispositions |
| 1 — Inventory, contracts, safety seam | Typed read/command/event schemas; identities; fixtures |
| 2 — Shared broker reads | Extract client/session/cache under one owner |
| 3 — Execution transport | ArdenOne uses shared broker commands |
```
Nothing touches the real broker until Phase 3. Phases 0–2 can be "complete" with every test
green and the system never exercised. The first real test is the production cutover.

**GOOD**
```markdown
### Phase 0: Walking Skeleton
**Goal:** one quote request traverses the new `ibkr-service`, the data API and the Trading MCP
and returns a real IBKR quote.
**Real dependency exercised:** the IBKR gateway, through a recorded-session replay harness
(`scripts/replay-gateway.sh fixtures/session-2026-09-04/`) that can be re-run on demand; one
live read per day against the sandbox account proves the recording is current.
**Retires or shadows:** shadows the legacy `get_market_snapshot` tool — both answers logged,
diff reported, legacy still authoritative.
**Does NOT include:** order placement, session handoff, any second capability.
**Exit criteria:** `pnpm run phase0` exits 0 with a quote whose fields match the legacy
snapshot for SPY within the recorded tolerance.
```
The riskiest dependency is exercised in week one, repeatably, without a production event, and
the slice retires something.

---

## Open Question (the right way to defer)

**WEAK** (a buried TBD)
```markdown
Retention policy: TBD.
```

**GOOD** (parked, owned, scheduled)
```markdown
## 16. Open Questions
3. **Fetch-history retention window.** How long does `linkapi` keep per-link fetch history before
   pruning? Affects the §7 schema (a `fetched_at` index) and storage growth. Owner: product.
   Resolve by: end of Phase 1. Impact if wrong: a late schema migration on a populated table.
```
The schema section then writes the index but notes "(retention window: see Open Question 3)"
instead of silently guessing.
