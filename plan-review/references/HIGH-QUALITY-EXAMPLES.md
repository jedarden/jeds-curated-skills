# High-Quality Plan Examples

Concrete examples of each pattern done well, drawn from the 88-document corpus.
Use when drafting missing sections or explaining to a user what "good" looks like.

---

## Acceptance Scenarios — Well-Written Example

From `process_triage` and `eidetic_engine_cli` style:

```markdown
### Scenario 3: Crash Recovery
**Setup:** System is mid-write when process is killed (SIGKILL).
**Action:** User restarts the tool and runs it normally.
**Expected:** Tool detects incomplete write, recovers from the last good checkpoint,
and reports: "Recovered from interrupted write at offset 4,821. No data lost."
**Pass criteria:**
- Output matches pre-crash state exactly
- Recovery message shown
- No manual intervention required
**Fail criteria:**
- Corrupted state silently accepted
- User required to manually delete temp files
- Recovery takes more than 2 seconds
```

---

## Non-Goals with Rationale — Well-Written Example

From `frankensqlite` and `flywheel_gateway` style:

```markdown
## Non-Goals (v1)

**Not a distributed system.**
This is a single-node embedded library. Distribution, replication, and consensus
are explicitly out of scope. The right tool for distributed workloads is a purpose-built
distributed database. Adding distribution to this scope would triple implementation time
and introduce a class of correctness problems that are not our expertise.

**No TCL scripting interface.**
The original SQLite ships a TCL harness for its own test suite. We replace this with
proptest + our conformance harness. No external consumers depend on our TCL interface
because we are not providing FFI symbols — we are reimplementing behavior.

**No Windows support in v1.**
Our target deployment environments are Linux and macOS. Windows requires a separate
I/O abstraction layer and different async primitives. We will revisit after v1 ships
if there is demonstrated demand.
```

---

## Risk Register — Well-Written Example

From `frankensqlite` and `frankenfs` style:

```markdown
## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | WAL mode interaction with async I/O produces torn writes under crash | Medium | Critical | Property-based crash tests with fault injection on every I/O call |
| R2 | Conformance divergence in floating-point edge cases | Medium | High | Byte-level round-trip tests against reference SQLite on every CI run |
| R3 | Phase 4 LOC estimate is 2x reality | High | Medium | Source metrics analyzed in §3; risk accepted; Phase 4 has explicit cut list if scope exceeded |
| R4 | Contributor unfamiliar with async Rust produces data races | Low | High | `#![forbid(unsafe_code)]`; loom tests for all shared state |
| R5 | asupersync API breaks between our Phase 2 and Phase 5 | Low | High | Pin asupersync version in `Cargo.lock`; integration test on every asupersync update |
```

---

## Phase Completion Criteria — Well-Written Example

From `eidetic_engine_cli` and `cass_memory_system` style:

```markdown
### Phase 2: Storage Layer

**Delivers:** Persistent indexed storage with ACID guarantees.

**Completion criteria (all must pass on the same commit):**
- `cargo test storage::` — 100% pass, 0 flaky
- `cargo test conformance::` — round-trip tests pass against reference data
- `cargo bench storage_write` — p99 < 2ms for 1KB records on reference hardware
- `cargo clippy -- -D warnings` — clean
- Manual test: kill process mid-write 10 times; all 10 recover cleanly on restart

**Does NOT include:**
- Query engine (Phase 3)
- Replication (non-goal)
- Migration tooling (Phase 5)

**Entry criteria (from Phase 1):**
- Type system compiles without warnings
- All Phase 1 unit tests pass
- Walking skeleton demo runs end-to-end
```

---

## Edge Case Catalog — Well-Written Example

From `process_triage` and `meta_skill` style:

```markdown
## Edge Case Catalog

**EC-01: Empty Input**
- Description: Tool invoked with zero items to process
- Resolution: Return immediately with exit code 0 and message "Nothing to process."
  Do not treat as an error. Callers rely on this behavior for idempotent scripts.

**EC-02: Input Larger Than Memory Budget**
- Description: Input set exceeds configured memory limit
- Resolution: Stream in chunks of `chunk_size` (default: 10,000 items).
  If chunk_size not set and input > 100MB, emit warning and use streaming automatically.
  Never load full input into memory regardless of available RAM.

**EC-03: Concurrent Invocations**
- Description: Two instances started against the same state directory
- Resolution: Second instance detects lock file, prints "Another instance is running
  (PID: N). Use --force to override." and exits with code 2.
  --force kills the prior instance and proceeds. Lock is advisory, not mandatory.

**EC-04: Permissions Error on State Directory**
- Description: State directory exists but is not writable
- Resolution: Fail immediately with clear message: "Cannot write to state directory
  /path. Check permissions. Run with --doctor to diagnose."
  Never silently fall back to a temp directory.
```

---

## ADR Format — Well-Written Example

From `frankentui` style:

```markdown
### ADR-001: Output Format Strategy

**Decision:** JSON is the primary output format; ANSI terminal output is a rendering layer on top.

**Context:** We need both human-readable and machine-readable output.
The temptation is to add `--json` as an afterthought. This produces divergent codepaths
and subtle differences between what humans and machines see.

**Rationale:** By treating JSON as primary and terminal rendering as a view over it,
we get: (a) free testability of output content, (b) stable machine API without coupling
it to terminal formatting decisions, (c) ability to regenerate terminal output from
stored JSON (replay/debug).

**Consequences:**
- All commands produce structured data internally before rendering
- Terminal output may lag behind JSON output in feature completeness (acceptable)
- `--json` flag is always available and always complete

**Rejected alternative:** Separate `--json` flag producing a different codepath.
Rejected because: historical evidence shows these diverge within 3 months.

**Invalidation trigger:** If performance profiling shows the JSON intermediate
representation adds >5% overhead on the hot path, reconsider.
```

---

## Normative Language Declaration — Well-Written Example

From `frankensqlite` style:

```markdown
### 0.2 Normative Language

The key words in this document follow RFC 2119:

- **MUST** / **MUST NOT** — absolute requirement; implementation fails spec if violated
- **SHALL** / **SHALL NOT** — synonym for MUST / MUST NOT
- **SHOULD** / **SHOULD NOT** — recommended; deviation requires documented rationale
- **MAY** — truly optional; no justification needed either way

When a section uses these words, they are binding. When prose uses them informally,
they are capitalized to distinguish normative from descriptive usage.
```

---

## Proof Obligations Ledger — Well-Written Example

From `meta_skill` and `eidetic_engine_cli` style:

```markdown
## Proof Obligations Ledger

Decisions that could be wrong, and how we'd know.

| Decision | What Must Be True | Invalidation Signal | Fallback |
|----------|------------------|---------------------|----------|
| DuckDB is fast enough for our query patterns | p99 query time < 50ms at 1M rows | Benchmark shows >50ms before Phase 3 | Switch to SQLite + custom indexes |
| Streaming output is sufficient for TUI consumers | All TUI consumers can buffer until newline | Consumer reports dropped frames | Add frame-boundary signaling |
| Single-writer architecture handles our concurrency | Max concurrent writers = 1 in all deployment scenarios | User reports data loss or lock contention | Add optimistic locking in Phase 4 |
```

---

## Walking Skeleton — Well-Written Description

From `eidetic_engine_cli` and `cass_memory_system` style:

```markdown
### Phase 0: Walking Skeleton

**Goal:** Prove the wiring works. Nothing is production-quality. Everything can be
thrown away. The only requirement is that a user can run one full end-to-end command
and see a real result.

**Delivers:**
- Binary compiles and runs
- One command (`status`) works end-to-end, touching every layer: CLI → logic → storage → output
- Storage writes and reads a real record
- Output renders in both human and JSON mode

**What Phase 0 explicitly does NOT include:**
- Error handling (panics are acceptable)
- Performance (correctness only)
- Tests (beyond "does it compile and run")
- Any command other than `status`

**Exit criteria:**
```bash
$ ./tool status --json
{"version": "0.0.1", "records": 0, "status": "ok"}
```
That's it. One command, one real response.
```
