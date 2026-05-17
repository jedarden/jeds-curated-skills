# Checklist 10 — API & Interface Design

Interface decisions are the hardest to change post-launch.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **10.1 Dual Output Surfaces**
  Human-readable output AND machine-readable (JSON / structured) output.
  The machine-readable format is versioned and treated as primary.
  Specified before implementation — harder to add after the fact.

- [ ] **10.2 Agent / Pipe Compatibility**
  - TTY detection
  - ANSI stripping in pipe mode
  - stdin / stdout piping contracts
  Specified at design time for any tool meant to compose with others.

- [ ] **10.3 API Surface Definition**
  Public API defined (function signatures, CLI flags, config keys) before
  implementation begins. Prevents "we need to break the API" moments.

- [ ] **10.4 Versioning Strategy**
  How API, data format, and config format versions are managed.
  What constitutes a breaking change and what the upgrade path looks like.

- [ ] **10.5 Token / Output Budget (AI-native tools)**
  If the tool is consumed by AI agents:
  - Compact output formats specified
  - Token budgets defined
  - Streaming contracts stated
