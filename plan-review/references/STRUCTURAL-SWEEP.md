# Structural Sweep — the safety net

Lens E. One pass, one file. These are the section-level patterns that high-quality plans share;
their absence *correlates* with pivots but does not cause them — unmade decisions do (Lens A).
So this sweep is demoted: it runs after the ledger, it allows **N/A**, and only applicable
MISSING / PARTIAL items reach the memo body. The full table goes in the appendix.

Rate each item **PRESENT / PARTIAL / MISSING / N/A (reason)**.
- PRESENT = sufficient to stop a pivot, not perfect.
- PARTIAL = mentioned but not actionable (one vague sentence; hedged with TBD).
- N/A = genuinely does not apply to this system or plan type — say why in four words.
  A 200-line offline CLI is not MISSING a per-threat security matrix.

`⇢ n.n` marks the ledger fork the item usually reduces to; when both fire, report the fork,
not the header.

---

## 01 Scope lock

| ID | Item | Bar |
|---|---|---|
| 1.1 | North star / one-sentence mission | Written before architecture; states what success *looks like* |
| 1.2 | Non-goals **with rationale** | Each exclusion says why and what would reopen it |
| 1.3 | Hard requirements / non-negotiables | MUST / MUST NOT incl. forbidden deps and patterns |
| 1.4 | Glossary | Every term two readers could read differently |
| 1.5 | Normative language declared | MUST/SHOULD/MAY defined once, used consistently |
| 1.6 | "What it is NOT" | Negative scope next to positive scope |
| 1.7 | Scope doctrine ⇢ 1.6 | How scope changes mid-flight (doc first, then code) |
| 1.8 | Self-contained background | A cold reader needs no external link to understand why |
| 1.9 | Date stamp / revision history | Stale plans cause pivots |

## 02 Acceptance

| ID | Item | Bar |
|---|---|---|
| 2.1 | Named acceptance scenarios | ≥3, "setup → action → expected", each independently verifiable |
| 2.2 | Pass **and** fail criteria per scenario | "It works" is not a criterion |
| 2.3 | Happy path is a named scenario | |
| 2.4 | Degraded / offline / error scenario | At least one thing goes wrong |
| 2.5 | Machine-mode scenario ⇢ 4.1 | If scripts or agents consume it |
| 2.6 | Success metrics: performance, functionality, adoption | Concrete numbers where numbers apply |

## 03 Architecture

| ID | Item | Bar |
|---|---|---|
| 3.1 | Component model | Named components, ownership, communication pattern |
| 3.2 | Data model / schema ⇢ 2.2–2.5 | Enough to spot a mismatch, not full DDL |
| 3.3 | State machine / request lifecycle | States and transitions named |
| 3.4 | Concurrency model ⇢ 3.1 | Shared state, ownership, what is thread-safe |
| 3.5 | Technology decisions with rationale ⇢ 1.1, 2.2 | Why X over Y, per key choice |
| 3.6 | Dependency contracts ⇢ 3.4 | Per external dep: surface used, forbidden, behaviour when unavailable |
| 3.7 | File / module layout | Proposed tree; "where does this go?" answered |
| 3.8 | **Decisions locked in place** ⇢ all | The 3–6 churn-magnets decided *in their home sections* in Decision form — not as ADRs appended at the end |
| 3.9 | Open questions with default + resolve-by gate | Each carries a recommended default and the phase it must close before |
| 3.10 | Cross-cutting concerns | Errors, logging, cancellation, encoding, observability — once, uniformly |
| 3.11 | Adjacent-system boundaries | What neighbours own; where this system's responsibility ends |

## 04 Pre-flight safety

| ID | Item | Bar |
|---|---|---|
| 4.1 | Edge case catalog | Numbered entries, each with a resolution; ≥5 for non-trivial systems |
| 4.2 | Failure modes & recovery ⇢ 3.4 | Taxonomy → recovery per type → a test per mode |
| 4.3 | Anti-patterns catalog | What not to do and why |
| 4.4 | Error taxonomy ⇢ 4.3 | Codes grouped by type with recovery actions |
| 4.5 | Rollback / state capture ⇢ 6.3 | Per destructive op: captured state, artifact, rollback command |
| 4.6 | Graceful degradation ⇢ 3.4 | Per network-dependent feature: works offline? what user sees? |
| 4.7 | Invariants | Named, testable, CI-enforced |
| 4.8 | Safe defaults | Destructive needs opt-in; default is the safe choice |
| 4.9 | Proof obligations / regret ledger | For bold claims: what must be true, what would invalidate it, fallback |

## 05 Phasing

| ID | Item | Bar |
|---|---|---|
| 5.1 | Named phases ⇢ 6.2 | Each with a one-paragraph "delivers" |
| 5.2 | Completion criteria per phase | Testable exit conditions, all on one commit |
| 5.3 | Walking skeleton ⇢ 6.1 | First deliverable is one command through every layer |
| 5.4 | Entry criteria / gates | Lint + test (+ bench) before the next phase starts |
| 5.5 | Size estimate | Rough LOC or effort per phase; ambition vs. capacity |
| 5.6 | Parallel vs. sequential tracks | Sync points named; ship order vs. phase number distinguished |

## 06 Testing

| ID | Item | Bar |
|---|---|---|
| 6.1 | Test strategy | Unit / integration / acceptance; stress or chaos for concurrent systems |
| 6.2 | Tests co-located with solutions | Each solution section names its tests |
| 6.3 | Property / fuzz tests | Required for parsing, serialization, protocol code |
| 6.4 | Conformance harness ⇢ 6.6 | Ports: output matches the original, byte-level |
| 6.5 | Stop-ship quality gates | "We do not ship if…" |
| 6.6 | All gates on the same commit | No "tests pass but bench broken" merges |
| 6.7 | Evidence bundle ⇢ 6.7 | What substantiates a performance/correctness claim, decided now |

## 07 Security

| ID | Item | Bar |
|---|---|---|
| 7.1 | Threat model ⇢ 5.1, 5.5 | Attacker, surface, impact — or an explicit "internal tool, because…" |
| 7.2 | Secrets handling ⇢ 5.3 | Stored where, never logged, rotated how |
| 7.3 | Audit logging ⇢ 5.6 | What is and is not logged |
| 7.4 | Untrusted input policy ⇢ 5.5 | Blanket, not per component |
| 7.5 | Supply chain | Pinning, checksums, update policy (when distributing code) |
| 7.6 | Threat → vector → mitigation → test matrix | When >3 threats |

## 08 Performance

| ID | Item | Bar |
|---|---|---|
| 8.1 | Numeric budgets ⇢ 6.7 | p50/p99, bytes, ops/s — stated as requirements |
| 8.2 | Benchmark denominator contract | Any "N× faster" bound to a methodology before coding |
| 8.3 | CI-gated benchmarks | Regression = build failure |
| 8.4 | Memory / allocation budget | For hot paths |
| 8.5 | Scalability limits | Where the design breaks, stated |

## 09 Operations

| ID | Item | Bar |
|---|---|---|
| 9.1 | Install / deploy path ⇢ 1.2 | Zero to running |
| 9.2 | Migration plan ⇢ 6.4 | Keep / drop / reinterpret matrix |
| 9.3 | Backward-compat stance ⇢ 4.5 | Stated even when "none" |
| 9.4 | Rollout / rollback criteria ⇢ 6.3 | When, how, go/no-go per rollout phase |
| 9.5 | Data format compatibility | Verified upfront when reading another tool's output |
| 9.6 | Non-interactive / CI mode | Every prompt has a bypass |
| 9.7 | Monitoring & alerting ⇢ 6.5 | What healthy looks like; what pages |
| 9.8 | Doctor / health check ⇢ 3.8 | Self-diagnosis before real workloads |

## 10 Interface

| ID | Item | Bar |
|---|---|---|
| 10.1 | Dual output surfaces ⇢ 2.5, 4.1 | Machine format primary and versioned |
| 10.2 | Pipe / agent compatibility | TTY detection, ANSI stripping, stdin/stdout contracts |
| 10.3 | Surface defined before code ⇢ 4.2 | Signatures, flags, config keys |
| 10.4 | Versioning strategy ⇢ 1.5 | What is breaking; upgrade path |
| 10.5 | Token / output budget ⇢ 4.8 | For agent-consumed tools |

## 11 Risk

| ID | Item | Bar |
|---|---|---|
| 11.1 | Risk register | Table: risk, likelihood, impact, mitigation; ≥5 for non-trivial |
| 11.2 | Plan B per top risk | "If X fails we do Y" |
| 11.3 | Ambition calibration | Aspirational vs. committed, labelled |
| 11.4 | Known unknowns ⇢ 3.9 | Each with a resolution strategy |
| 11.5 | Incident named (improvements) | The real failure that prompted this |

---

## Type-specific

### P — Port
| ID | Item |
|---|---|
| P.1 | Source metrics: LOC by subsystem before estimating target size |
| P.2 | Parity matrix (location · status · gaps), living |
| P.3 | Conformance harness on day one ⇢ 6.6 |
| P.4 | ABI / FFI stance: reimplement behaviour vs. symbol-compatible |
| P.5 | File-format round-trip tests |
| P.6 | Porting order by dependency layer |
| P.7 | Feature-flag strategy for gated features |
| P.8 | Toolchain pinned ⇢ 1.1 |

### I — Improvement
| ID | Item |
|---|---|
| I.1 | Gap inventory before solutions |
| I.2 | "What we're NOT changing" |
| I.3 | Incident class named |
| I.4 | Existing data-format compatibility ⇢ 2.3 |
| I.5 | Rollback criteria before rollout ⇢ 6.3 |
| I.6 | Behavioural regression tests written first |

### J — Integration
| ID | Item |
|---|---|
| J.1 | Post-integration ownership: A owns X, B owns Y, the seam owns Z |
| J.2 | Failure isolation: one side down ⇒ ? ⇢ 3.4 |
| J.3 | Data ownership & conflict resolution ⇢ 2.1 |
| J.4 | Contract versioning & breaking-change notice ⇢ 4.5 |
| J.5 | End-to-end test ownership |
| J.6 | Rollback coordination across sides ⇢ 6.3 |

### M — Migration / Cutover
| ID | Item |
|---|---|
| M.1 | Backup taken, restore rehearsed, before any destructive step ⇢ 2.9 |
| M.2 | Idempotent, resumable steps ⇢ 2.10 |
| M.3 | Shadow / canary period with a diff oracle |
| M.4 | Cut-over gate and rollback trigger, named ⇢ 6.3 |
| M.5 | Post-cutover validation and the retirement of the old path |

### S — Spike (a plan whose deliverable is a decision)
| ID | Item |
|---|---|
| S.1 | The question, as one sentence a measurement can answer |
| S.2 | Metrics and thresholds that decide it |
| S.3 | Environment(s) named (hardware, browsers, versions) |
| S.4 | Time box and decide-by date/gate |
| S.5 | Where the decision is recorded — *in the plan it informs*, not only in a research log |
| S.6 | Default if inconclusive |

For a Spike, categories 02–11 are mostly N/A; do not pad the memo with them.
