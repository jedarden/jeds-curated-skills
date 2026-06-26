# Checklist 04 — Communication & Documentation

A correct release that nobody knows how to use — or that silently breaks a downstream
consumer — still fails in production. These gates close the human loop.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **4.1 Docs / README Updated**
  User-facing documentation and the README reflect the new version's behavior, flags,
  and usage. Docs that still describe the prior version are MISSING.

- [ ] **4.2 Deprecations Announced with Timeline**
  Anything being deprecated is announced with a concrete removal timeline, not removed
  silently. A breaking removal with no prior deprecation window is flagged here.

- [ ] **4.3 Dependents / Consumers Notified**
  Known downstream consumers of a changed interface have been (or will be at release)
  notified of what changes for them. Unverified "they'll figure it out" is MISSING.

- [ ] **4.4 API Reference Regenerated**
  If the public API changed, generated reference docs (OpenAPI, typedoc, rustdoc, etc.)
  are regenerated and match the shipped code. Stale generated docs are MISSING.

- [ ] **4.5 Support / On-Call Briefed**
  Whoever is on-call for this release knows it is going out, what changed, and where the
  rollback and runbook live. An unannounced release to an unaware on-call is PARTIAL.
