# Checklist 01 — Quality Gates

The code must be provably shippable. These are the gates that block a release outright.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **1.1 Tests Pass**
  The full test suite runs green on the release ref — verified, not assumed.
  Find evidence: CI run on the release commit, or a local `test`/`check` invocation.

- [ ] **1.2 Lint / Format Clean**
  Linter and formatter report no violations on the changed paths.
  A configured linter that is never run is PARTIAL, not PRESENT.

- [ ] **1.3 Build Succeeds**
  The release artifact builds cleanly from a clean checkout.
  Cached or incremental-only builds do not count as evidence.

- [ ] **1.4 No Open P0 / P1**
  No known release-blocking defects remain open against this version.
  Check the issue tracker, blocker labels, or a stated "known issues" list.

- [ ] **1.5 Coverage Not Regressed**
  Test coverage on changed code has not dropped below the project's bar.
  New code paths without any test are a PARTIAL at best.

- [ ] **1.6 No Debug / TODO / FIXME in Shipped Paths**
  No leftover debug prints, commented-out blocks, TODO, FIXME, or XXX markers in
  files that ship. Scratch/test fixtures are exempt; production source is not.

- [ ] **1.7 Dependencies Pinned**
  Dependencies are locked to exact versions (lockfile committed, no floating ranges
  in the shipped manifest). An uncommitted or stale lockfile is MISSING.

- [ ] **1.8 No Critical CVEs**
  A dependency vulnerability scan shows no unaddressed critical/high advisories.
  No scan having been run at all is MISSING.
