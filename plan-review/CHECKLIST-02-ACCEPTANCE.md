# Checklist 02 — Acceptance Scenarios & Success Definition

Plans that don't define "done" before building always pivot.
Write the definition of done as named stories, not a feature list.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **2.1 Named Acceptance Scenarios**
  At least 3–5 narrative user stories in the format:
  "User does X → system does Y → user sees Z."
  Written *before* architecture, not after. Each independently verifiable.

- [ ] **2.2 Pass/Fail Criteria Per Scenario**
  Each scenario has explicit pass criteria AND explicit failure criteria.
  "It works" is not a criterion.

- [ ] **2.3 Happy Path Coverage**
  The primary use case is a named scenario.

- [ ] **2.4 Degraded / Offline / Error Scenarios**
  At least one scenario where something goes wrong — network down,
  bad input, dependency unavailable.

- [ ] **2.5 Agent / Automation Scenario**
  If the tool will be consumed by scripts or AI agents, at least one
  scenario covers machine-mode usage.

- [ ] **2.6 Success Metrics in Three Buckets**
  - Performance: concrete numbers (latency, throughput, size)
  - Functionality: what features are working
  - Adoption: usage signals that indicate real value delivered
  All three required for non-trivial projects.
