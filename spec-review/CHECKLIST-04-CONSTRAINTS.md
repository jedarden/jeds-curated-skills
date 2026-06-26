# Checklist 04 — Constraints, Assumptions & Boundaries

Unstated assumptions are landmines. The plan inherits every one the spec leaves buried.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **4.1 Explicit Assumptions**
  Every assumption the spec relies on is written down, not left implicit. Each is flagged so
  the plan can validate it before committing.

- [ ] **4.2 Dependencies Named**
  External systems, services, APIs, libraries, and teams the feature depends on are listed,
  including version or availability constraints.

- [ ] **4.3 Non-Goals / Out of Scope**
  What this spec deliberately does NOT cover is stated, each with a one-line rationale.
  Prevents scope creep and "I assumed it included X."

- [ ] **4.4 Deadline & Budget Constraints**
  Time, cost, headcount, or resource ceilings that shape the solution are stated if they
  exist, so the plan does not over-design.

- [ ] **4.5 Regulatory & Compliance Constraints**
  Legal, regulatory, data-residency, retention, or industry-compliance obligations that
  bind the design are identified — or explicitly declared not applicable.

- [ ] **4.6 Platform & Environment Constraints**
  Required platforms, browsers, devices, runtimes, or deployment targets are stated rather
  than assumed.

- [ ] **4.7 Open Questions Logged**
  Unresolved decisions are captured as a visible list with an owner, not silently deferred.
  An empty or absent open-questions section on a non-trivial spec is suspicious, not clean.
