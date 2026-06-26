# Checklist — Migration Safety

The bar every migration runbook must clear. A migration is only as safe as its weakest
unreversed step. Rate each: PRESENT / PARTIAL / MISSING

- [ ] **1.1 Per-Step Reversibility**
  Every procedure step has a rollback, or is explicitly marked a point-of-no-return.
  A step with neither is a defect — there is no third option.

- [ ] **1.2 Per-Step Verification Gate**
  Every step has an observable success signal that must pass before the next step runs.
  "It probably worked" is not a gate; a query result, metric, or status code is.

- [ ] **1.3 Idempotency / Safe Re-Run**
  Each step is safe to re-run if interrupted partway. Re-running yields the same end state,
  not duplicated rows or doubled side effects.

- [ ] **1.4 Dry-Run Available**
  The procedure can be exercised against a copy or in no-op mode before committing,
  and the dry-run's expected output is stated.

- [ ] **1.5 Explicit Abort Criteria**
  The conditions that stop the migration are pre-committed (thresholds, lag, gate failures),
  decided before execution — not improvised during an incident.

- [ ] **1.6 Backup / Snapshot Before Destructive Steps**
  Every irreversible or data-mutating step is preceded by a backup/snapshot step,
  and the backup's restore path is tested — not assumed.

- [ ] **1.7 Monitoring / Observability During Cutover**
  The signals to watch during the cutover are named, with dashboards/queries and the
  healthy-vs-problem thresholds. You can see the migration as it happens.

- [ ] **1.8 Points-of-No-Return Clearly Marked**
  Every irreversible step carries a loud banner, names the recovery path (snapshot restore /
  reverse migration), and states the last safe abort point before it.

- [ ] **1.9 No Big-Bang**
  Rollout is incremental, canary, or phased wherever the pattern allows. A single
  all-at-once cutover is justified only when the pattern genuinely permits nothing else.

- [ ] **1.10 Rollback Tested Before First Irreversible Action**
  The rollback procedure has been exercised (in staging or via dry-run) before the runbook
  reaches its first point-of-no-return. An untested rollback is a hope, not a plan.

- [ ] **1.11 Validation Gates Between Phases**
  Phase boundaries have go/no-go gates with pass/fail criteria (data parity, error rate,
  drained-for-N-minutes) — a failed gate routes to the abort path.

- [ ] **1.12 RPO/RTO and Recovery Time Bounded**
  Estimated rollback time is stated and is within the recovery-time objective; the backup
  cadence satisfies the recovery-point objective.
