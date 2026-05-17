# Checklist 08 — Performance Budgets & Benchmarks

Performance requirements stated after implementation = rewrites.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **8.1 Performance Budgets with Hard Numbers**
  Latency / throughput targets as numeric SLOs stated in requirements,
  not in an optimization section. "Fast enough" is not a budget.
  Format: p50 / p99 / p999 tables, or bytes/frame, or ops/sec.

- [ ] **8.2 Benchmark Denominator Contract**
  Any "X times faster than Y" claim bound to a specific measurement methodology
  before coding begins. Prevents benchmark theater mid-project.

- [ ] **8.3 CI-Gated Benchmarks**
  Benchmarks are CI-gated, not advisory. A regression is a build failure.

- [ ] **8.4 Memory / Allocation Budget**
  For performance-sensitive code: allocation budget per hot path.
  "Zero allocation in the render loop" must be stated before writing the loop.

- [ ] **8.5 Scalability Limits**
  At what input size or load does the design break?
  Stated explicitly so it's a known boundary, not a surprise.
