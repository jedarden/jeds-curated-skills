# Checklist 03 — Operational Readiness

Operational problems discovered after deploy are the most expensive failures. A release with
no way back is the single most common cause of a prolonged incident.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **3.1 Rollback Plan Exists**
  There is an explicit, tested way to revert to the previous release.
  "Redeploy the old tag" only counts if state changes (3.2) are also reversible.
  A release with no rollback path is a hard blocker.

- [ ] **3.2 Migrations Reversible & Ordered**
  Any DB or data migration has a down/revert path, runs in a defined order, and is
  forward/backward compatible with both the old and new app version during rollout.
  An irreversible destructive migration shipped alongside code is a hard blocker.

- [ ] **3.3 Feature Flags Default-Safe**
  New behavior gated behind flags defaults to off (or to the prior behavior), so the
  deploy is decoupled from the activation. Flags that default on with no kill switch are PARTIAL.

- [ ] **3.4 Monitoring & Alerts Cover New Surface**
  New endpoints, jobs, or code paths emit metrics/logs and have alerts on their failure
  modes. Shipping a new surface that is invisible to monitoring is MISSING.

- [ ] **3.5 Config & Secrets in Place for Target Env**
  Every new config key and secret the release needs already exists in the target
  environment. A release that requires a not-yet-provisioned secret is a hard blocker.

- [ ] **3.6 Runbook Updated**
  The operational runbook reflects the new behavior: how to operate it, what the new alerts
  mean, and how to respond. New on-call surface with no runbook entry is PARTIAL.
