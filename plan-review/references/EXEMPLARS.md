# Exemplars — what locked looks like, and what this skill exists to catch

Forms first (use these when proposing or writing a decision), then worked examples, then the
anti-patterns. Forms are distilled from the strongest plans in a ~340-document corpus of
planning documents and from this workspace's own plans; examples are written fresh in those
forms, not copied.

---

## Form 1 — the compact inline Decision (default)

Five lines, placed *where the implementer will read it* (the Architecture, Data, or
Infrastructure section — not an appendix):

```markdown
**State store: SQLite, single writer — not a flat JSON file.**
**Because:** a JSON file rewrites the whole document per update and has no crash-safe partial
write; SQLite gives atomic writes, indexed lookup by URL, and a WAL we already run elsewhere.
**Rejected:** Postgres — a second stateful service for a tool §6.3 fixes at one writer.
**Enforced by:** `replicas: 1` is an invariant (§8.3); `store::second_writer_is_refused` test.
**Revisit if:** a second writer is ever required — that is a redesign, not a config change.
```

Every line earns its place: *Because* makes it defensible, *Rejected* stops the next reader
from re-litigating, *Enforced by* makes it true rather than aspirational, *Revisit if* makes
reopening legitimate instead of sneaky.

## Form 2 — Problem → Options → Decision → Tests (for genuinely contested forks)

When two options are both credible, show the work — but still inline, still ending in tests:

```markdown
### Inline rendering strategy

**Problem.** Stable UI chrome plus scrollback-native logs, no flicker, across terminals and
multiplexers.

**Options.**
A. Scroll-region anchoring — truly pinned UI; fragile under cursor save/restore and tmux.
B. Overlay redraw — portable, correctness-first; needs careful region clearing to avoid flicker.
C. Hybrid — B as baseline, A as an optimisation enabled only where proven safe.

**Decision: C.** Overlay redraw is always available and is the correctness baseline; scroll-region
anchoring is internal, capability-gated, and never part of the public API (which exposes policy,
not mechanism).

**Tests (stop-ship).** PTY test: log spam + UI tick neither corrupts scrollback nor drifts the
cursor; same test under tmux with the optimisation forced off and forced on.
```

## Form 3 — the well-parked Open Question (recommended default + answer plan + gate)

An open question is acceptable only when someone can close it with one word:

```markdown
## Open Questions

3. **Fetch-history retention window.** Affects the §7 schema (`fetched_at` index) and storage
   growth. **Recommended default: 90 days**, pruned by the existing maintenance loop — long
   enough for the monthly report, short enough that the table stays under 1 GB at current
   volume. **Answer plan:** confirm with the report owner; if they need >90 days, add a
   per-source override rather than raising the global. **Resolve by:** end of Phase 1 (before
   the table is populated). **If wrong:** a late migration on a populated table.
```

The body then says "(retention: see Open Question 3)" at the schema — never a silent guess.

## Form 4 — the Spike (when the armchair cannot decide)

```markdown
### Spike: WebGPU vs. Canvas renderer (decides §6.2)

**Question.** Can `wgpu` on wasm32 render 10k agents + food grid at ≥30 FPS on mid-range
hardware, or do we ship Canvas2D?
**Metrics.** FPS at 5k and 10k agents; frame time split (sim vs. render); wasm + JS bundle
size (gzip); pan/zoom input latency.
**Environment.** Chrome 139 (Windows), Safari 26 (macOS), Firefox current (Linux).
**Time box.** Two weeks; results logged in `docs/research/rendering-spike.md`.
**Decide by.** Phase 3 entry. The decision is written into §6.2 in Form 1 — the research log
is evidence, not the record.
**Default if inconclusive.** Canvas2D (works everywhere; WebGPU becomes an optional backend).
```

## Form 5 — the `DECISION NEEDED` callout (what `--lock` leaves for the human)

```markdown
> **DECISION NEEDED (DN-2): container registry.** The plan says "target TBD".
> **Recommended:** `ronaldraygun/<name>`, public — the image contains no account-specific
> content, and every other template in this environment pushes there; a private registry
> would need new pull secrets on the cluster. **Resolve by:** Phase 5 (first CI build).
> To adopt: `/plan-review --lock DN-2`.
```

## Form 6 — the binding measurement contract (for any "N× faster" or "p99 < X" claim)

```markdown
**Benchmark denominator (binding).** The "≥3×" claim is suite-level over Benchmark Suite v1.0
(§14): weighted geometric mean of per-case throughput vs. the pinned baseline, on identical
hardware, warm and cold cache, fixed seeds, median of 5 runs with dispersion reported. A case
that fails the equivalence gate scores as non-passing and blocks publication. Raw per-run
artifacts and a repro script are published with every claim.
```

## Form 7 — proof obligations (per change, for optimisations)

```markdown
Every optimisation commit carries an isomorphism note: ordering preserved, tie-breaking
preserved, floating-point decisions unchanged, scalar fallback preserved, golden checksums
preserved, determinism script green, and a same-host p95 delta that exceeds the variance
envelope before any speedup is claimed.
```

---

## Worked examples of the other load-bearing sections

### Acceptance scenario
```markdown
### Scenario 3: Remote unreachable mid-sync
- **Setup:** 500 files queued; network drops after 200 are uploaded.
- **Action:** `syncd push`.
- **Expected:** upload halts; the 200 committed files stay committed; exit 75; message
  "Network lost after 200/500. Re-run `syncd push` to resume; no files were corrupted."
- **Pass:** exit 75; the 200 match source checksums; re-run resumes at file 201; zero partial
  files on the remote.
- **Fail:** any partially written remote file; exit 0 despite incomplete sync; resume re-uploads
  committed files.
```

### Phase with completion criteria
```markdown
### Phase 2: Storage layer
**Delivers:** persistent indexed storage with ACID guarantees.
**Completion (all on one commit):** `cargo test storage::` 100% pass, 0 flaky ·
`cargo test conformance::` round-trips reference data · `cargo bench storage_write` p99 < 2 ms
for 1 KB records on the reference box · clippy clean · kill -9 mid-write ×10, all recover.
**Does NOT include:** query engine (Phase 3), replication (non-goal), migration tooling (Phase 5).
**Entry (from Phase 1):** walking skeleton demo runs end-to-end; Phase 1 tests green.
```

### Walking skeleton
```markdown
### Phase 0: Walking skeleton
One command, every layer, throwaway quality. `./tool status --json` prints
`{"version":"0.0.1","records":0,"status":"ok"}` after touching CLI → logic → storage → output.
No error handling (panics are fine), no performance, no other command. That is the whole exit
criterion.
```

### Edge case entry
```markdown
**EC-03: Concurrent invocations against one state directory.** The second instance detects
the lock file, prints "Another instance is running (PID n). Use --force to override." and exits
2. `--force` kills the prior instance and proceeds. The lock is advisory.
```

### Non-goal with rationale
```markdown
**No real-time sync.** `syncd` reconciles on an explicit invocation or a timer, not on
filesystem events. Watching would need a per-OS watch layer and a crash-surviving in-memory
index — a class of bugs that buys nothing for users who sync on a schedule. Reopen if a user
demonstrates a sub-minute freshness need.
```

### Risk register row
```markdown
| R3 | Phase 4 LOC estimate is 2× reality | High | Medium | Source metrics analysed in §3; risk accepted; Phase 4 carries an explicit cut list |
```

---

## Anti-patterns — what this skill exists to catch

| Seen in real plans | Why it is a pivot in waiting | State |
|---|---|---|
| `## ADR-001: Ratify Go as the implementation language` at line 1084 of 1109, after Open Questions, dated after the plan "passed review" | The language was undecided while the plan was called READY; the decision lives where no implementer reads | SHADOW |
| `- **Performance:** [FILL IN once real data volume is known]` | A placeholder shipped as a section; the number was never going to arrive on its own | DEFERRED |
| `HTTP server (Rust, likely axum)` | "Likely" is a fork left to whoever types `cargo add` first | DEFERRED |
| `Docker build → registry (target TBD, see Open Questions)` | The Open Question has no default; CI cannot be written | DEFERRED |
| `Backup interval — candidate default: every 15 minutes?` as a question, never moved into the body | A recommended default that never locked is still a fork | RECOMMENDED, un-endorsed |
| A cache of "every 2xx, forever" with no classification of time-varying vs. immutable responses | Became a 9-day silent-staleness incident and two contradictory ADRs | UNNOTICED |
| "decided 2026-07-20" inside a 900-word Open Questions paragraph; the Architecture section still shows the old value | Two sources of truth in one document | SHADOW |
| `Phase 2: Caching layer` as a checkbox with no completion criteria | "Done" is whatever the worker who closed the bead thought | PARTIAL (5.2) |
| A plan scored "88% present, 0 missing" whose first phase was blocked for five days | Percentages measured headers, not decisions | — (why this skill changed) |
