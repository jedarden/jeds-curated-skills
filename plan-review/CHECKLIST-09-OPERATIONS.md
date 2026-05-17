# Checklist 09 — Deployment, Migration & Rollback

Operational problems discovered after launch are the most expensive pivots.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **9.1 Installation / Deployment Plan**
  How does a user get from zero to running?
  For services: deployment topology. For CLIs: distribution method and install path.

- [ ] **9.2 Migration Plan**
  If replacing or evolving an existing system: explicit migration path.
  Keep / Drop / Reinterpret matrix for all prior decisions and data formats.

- [ ] **9.3 Backward Compatibility Stance**
  Stated explicitly even when the answer is "none."
  Implicit backward compatibility assumptions are a common pivot source.

- [ ] **9.4 Rollout / Rollback Criteria**
  - When do you roll back?
  - What does rollback look like mechanically?
  - Go / No-Go checklist for each phase of rollout.

- [ ] **9.5 Data Format Compatibility**
  If reading or writing data produced by another tool: format compatibility
  verified and tested upfront, not assumed.

- [ ] **9.6 Non-Interactive / CI Mode**
  All user prompts have a non-interactive bypass.
  Automation is a first-class citizen, not an afterthought.

- [ ] **9.7 Monitoring & Alerting**
  What does a healthy system look like?
  What signals indicate a problem?
  For services: SLO definitions and alert thresholds.

- [ ] **9.8 Doctor Command / Health Check**
  For CLI tools: a `doctor` or `check` subcommand that verifies the installation
  and configuration is correct before the user runs real workloads.
  Treat as required, not optional.
