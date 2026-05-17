# Type-Specific Checks — Port Plans

A port rewrites existing code in another language or runtime.
These checks are in addition to the universal checklist.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **P.1 Source Metrics Analysis**
  Count existing LOC by subsystem before estimating target output size.
  Reveals when a "simple port" is actually 40,000+ lines of work.

- [ ] **P.2 Parity Matrix**
  Living table of every subsystem with columns: location | status | known gaps.
  Updated as implementation proceeds. Surfaces all unknown unknowns upfront.

- [ ] **P.3 Conformance Harness on Day One**
  Byte-level comparison tests against the original system specified before
  any implementation begins — not added after the port "seems to work."

- [ ] **P.4 ABI / FFI Stance**
  Explicitly states whether the port reimplements behavior (no C ABI exposure)
  or must be drop-in compatible at the symbol level. Common source of late pivots.

- [ ] **P.5 File Format Round-Trip Tests**
  Write with new implementation → verify with original.
  Read original format with new implementation → verify structure.

- [ ] **P.6 Porting Order Defined**
  Order follows dependency layers: types → I/O → data structures → transactions → CLI.
  Never skips a layer. Reverse-round ordering (most dependent first) for large systems.

- [ ] **P.7 Feature Flag Strategy**
  Compile-time feature flags replace runtime dynamic loading.
  Explicit statement of which features are gated for v1 vs. future work.

- [ ] **P.8 `rust-toolchain.toml` or Equivalent Pinning**
  Toolchain version pinned to avoid nightly breakage. Required for Rust ports.
