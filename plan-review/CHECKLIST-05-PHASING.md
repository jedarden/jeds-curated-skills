# Checklist 05 — Implementation Phasing & Gates

Unphased plans make it impossible to know if you're on track.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **5.1 Phased Delivery with Named Phases**
  Implementation broken into phases (minimum 3), each with:
  - A name
  - A one-paragraph description of what it delivers

- [ ] **5.2 Phase Completion Criteria**
  Each phase has explicit, testable completion criteria — not just a task list.
  "Phase 2 is done when X, Y, and Z pass" not "Phase 2: implement caching."

- [ ] **5.3 Walking Skeleton as Phase 0 / 1**
  First deliverable is a minimal end-to-end system that can be demonstrated,
  even if most features are stubbed. Proves the wiring works before building on it.

- [ ] **5.4 Phase Entry Criteria**
  Each phase can only begin after the previous phase passes defined quality gates
  (lint + test + bench at minimum). Prevents "building on a broken foundation."

- [ ] **5.5 LOC / Scope Estimate**
  For non-trivial projects: rough estimate of implementation size per phase.
  Reveals scope mismatch between plan ambition and available time.

- [ ] **5.6 Parallel vs. Sequential Tracks**
  If work can proceed in parallel, tracks are named and synchronization points
  identified. Hidden sequencing assumptions cause bottlenecks.
