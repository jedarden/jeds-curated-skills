# Checklist 03 — Architecture & Design Completeness

Gaps here cause "wait, how does X actually work?" pivots.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **3.1 Architecture Overview / Component Model**
  Major components named, each with ownership and communication pattern.
  A diagram or structured description.

- [ ] **3.2 Data Model / Schema**
  Core data structures, database tables, or wire formats defined at design level.
  Enough to spot model mismatch early — not necessarily full DDL.

- [ ] **3.3 State Machine / Request Lifecycle**
  If the system has state: states and transitions named.
  If it processes requests: the full lifecycle described.

- [ ] **3.4 Concurrency Model**
  How is shared state managed? What is thread-safe vs. not?
  What is the ownership model? Critical for any concurrent system.

- [ ] **3.5 Technology Stack Decisions with Rationale**
  Why X over Y for each key choice. Undecided technology choices at plan
  time become mid-implementation arguments.

- [ ] **3.6 Dependency Integration Contracts**
  For each external dependency:
  - Exact API surface used
  - What is explicitly forbidden
  - Behavior when the dependency is unavailable

- [ ] **3.7 File / Module Layout**
  Proposed directory structure or crate layout defined upfront.
  Prevents "where does this go?" churn.

- [ ] **3.8 ADRs for Churn-Magnets**
  The 3–6 most contentious design decisions locked as Architecture Decision Records
  before implementation begins. Common churn-magnets:
  output format (human vs. JSON), async runtime, storage backend, extension model.

- [ ] **3.9 Open Questions with Resolution Deadlines**
  Every unresolved design question named and tagged "resolve before Phase N."
  Untracked open questions become pivots.

- [ ] **3.10 Cross-Cutting Concerns Section**
  Error handling, logging, cancellation, encoding, and observability addressed
  once, uniformly — not ad-hoc per module.

- [ ] **3.11 Sibling / Adjacent System Boundaries**
  What do neighboring tools or services own?
  Where exactly does this system's responsibility end?
  Prevents accidental reimplementation.
