# Checklist 02 — Versioning & Release Notes

A release that users cannot reason about is a support burden. These gates make the change
legible and the artifact trustworthy.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **2.1 Version Bumped per Semver**
  The version number is incremented correctly for the change set: patch for fixes,
  minor for additive features, major for breaking changes.
  A feature shipped under a patch bump is MISSING (wrong bump), not PRESENT.

- [ ] **2.2 Changelog Updated**
  The CHANGELOG has an entry for this version with user-facing, human-readable items —
  not a raw commit dump. An empty or unchanged changelog for a non-trivial release is MISSING.

- [ ] **2.3 Breaking Changes Documented**
  Every breaking change is called out explicitly with migration notes telling consumers
  what to change. A major bump with no breaking-change section is MISSING.

- [ ] **2.4 Release Notes / Tag Message Drafted**
  Release notes (or the annotated tag message) are written and ready to publish with the tag.
  Highlights, upgrade steps, and known issues are covered.

- [ ] **2.5 Artifacts Reproducible**
  The release artifact can be rebuilt from the tagged source and matches — pinned toolchain,
  pinned deps, deterministic build. "Works on my machine" builds are PARTIAL.

- [ ] **2.6 Version Consistency**
  The version is consistent across every place it appears (manifest, lockfile, code constant,
  docs, container tag). A mismatch between them is MISSING.
