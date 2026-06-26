# Checklist 03 — Completeness & Non-Functional Coverage

Specs over-describe the happy path and forget the other 80%. The gaps surface as pivots.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **3.1 Performance Requirements**
  Latency, throughput, resource limits, and load expectations are stated with numbers,
  not implied.

- [ ] **3.2 Security & Privacy Requirements**
  Authentication, authorization, data sensitivity, secrets handling, and threat exposure
  are addressed — or explicitly declared out of scope with rationale.

- [ ] **3.3 Accessibility & Internationalization**
  If user-facing: accessibility expectations (contrast, keyboard, screen reader) and
  localization/locale handling are specified or consciously excluded.

- [ ] **3.4 Scale & Capacity**
  Expected data volumes, user counts, growth, and the limits the system must hold at are
  stated. "Scales as needed" is MISSING.

- [ ] **3.5 Error, Empty & Degraded States**
  Behavior on invalid input, empty data, partial failure, dependency outage, and timeout is
  specified — not just the success path.

- [ ] **3.6 Edge Cases Enumerated**
  Boundary inputs, concurrent actions, duplicate requests, and unusual-but-valid states are
  listed, not left to the implementer to imagine.

- [ ] **3.7 Data Lifecycle**
  Creation, validation, storage, retention, deletion, export, and migration of data are
  covered. Where does data go when a user leaves?

- [ ] **3.8 Permissions & Roles**
  Distinct user roles and what each may and may not do are defined. Default-deny vs.
  default-allow is explicit.

- [ ] **3.9 Observability Requirements**
  What must be logged, measured, or alertable for the feature to be operable is stated.
