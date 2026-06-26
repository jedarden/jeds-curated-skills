# Migration Runbook Template

Fill every section. Do not delete a section because it "doesn't apply" — write
"N/A — <reason>" so a reader knows it was considered, not forgotten. Every numbered
procedure step uses the **Action / Verify / Rollback** triad. Mark any irreversible step
with a `⛔ POINT OF NO RETURN` banner.

---

## 1. Objective & Scope

- **What is moving:** From `<source>` → To `<target>`.
- **Why:** one sentence on the driver.
- **In scope:** the systems, schemas, datasets, and traffic this runbook touches.
- **Out of scope:** explicitly listed. Anything not here is not changed by this runbook.
- **Migration pattern:** `<expand-contract | dual-write+backfill | shadow | blue-green | canary | strangler-fig>`
- **Downtime tolerance:** `<zero | maintenance window of N min | best-effort>`
- **RPO / RTO:** max acceptable data loss `<N>` / max acceptable recovery time `<N>`.

## 2. Blast Radius

What breaks if this goes wrong, in concentric rings:
- **Direct:** the components being migrated.
- **Downstream:** consumers, dependent services, scheduled jobs, dashboards.
- **Data:** which records are mutated/copied/deleted and whether the change is recoverable.
- **Worst case:** the single worst outcome and its likelihood.
- **Owners to notify:** teams/individuals who must know before and during.

## 3. Prerequisites & Pre-Checks

Run all of these **before** starting. The migration does not begin until every check passes.

- [ ] Access/credentials to source and target confirmed.
- [ ] Source and target health green (link dashboards / commands).
- [ ] Backup/snapshot capability verified (see §9 — do not trust an untested backup).
- [ ] Rollback path tested in a non-production environment (see §8).
- [ ] Maintenance window booked / comms drafted (see §10) if downtime is non-zero.
- [ ] Feature flag / kill switch wired and confirmed togglable (if pattern uses one).
- [ ] Free disk / quota / connection headroom for the backfill confirmed.
- [ ] `[FILL IN: any environment-specific pre-check]`

**Pre-check command(s):**
```
<commands that print PASS/FAIL for each prerequisite>
```

## 4. Dry-Run

Prove the procedure works without committing to it.
- **How to dry-run:** `<flag/env/target that runs the migration against a copy or in no-op mode>`
- **What it validates:** schema diff, row counts, transform correctness, timing estimate.
- **Expected output:** `<the exact result that means "safe to proceed">`
- **If the dry-run diverges:** stop. Do not proceed to §5. Reconcile first.

## 5. Step-by-Step Procedure

Each step is atomic and idempotent (safe to re-run). Number them. For each:

### Step 5.N — `<short title>`
- **Action:** the exact command(s) / change to apply.
- **Verify:** the observable signal that the action succeeded (a query result, metric,
  status code, log line). The next step does not start until this passes.
- **Rollback:** the exact command(s) to undo *this* step, or a reference to §8 if it is a
  composite rollback. If the step is irreversible, state it here and add the banner:

  > ⛔ POINT OF NO RETURN — after this step, rollback requires `<snapshot restore / reverse migration>`,
  > not a simple undo. Last safe abort point is Step 5.`<M>`. Get explicit go/no-go before running.

Order steps so all reversible work happens first and irreversible steps are clustered late
and minimal. Prefer incremental/canary progression over a single big-bang cutover.

## 6. Validation Gates

Between phases, a gate that must be green to continue. Define each gate's pass/fail:
- **Gate A (after expand/backfill):** `<row-count parity, checksum match, lag < N>` → pass/fail.
- **Gate B (after canary % shift):** `<error rate < baseline, p99 within budget>` → pass/fail.
- **Gate C (before contract/cleanup):** `<old path fully drained for N minutes>` → pass/fail.
A failed gate triggers the abort criteria in §7.

## 7. Abort Criteria

Pre-commit to the conditions that stop the migration — decided now, not mid-incident:
- Error rate exceeds `<threshold>` for `<duration>`.
- Replication/backfill lag exceeds `<threshold>`.
- Data parity check fails (counts/checksums diverge).
- Any validation gate in §6 fails.
- `<FILL IN: domain-specific tripwire>`
On any abort condition: stop forward steps, execute §8, then notify per §10.

## 8. Rollback Procedure

The reverse runbook. For each forward phase, the corresponding undo:
- **Pre-point-of-no-return:** undo steps in reverse order using each step's Rollback.
- **Post-point-of-no-return:** the recovery path — snapshot restore, reverse migration,
  traffic shift-back, or flag flip (cite the pattern from ROLLBACK-PATTERNS.md).
- **Rollback verification:** how you confirm the system is back to a known-good state
  (the same checks as §3 pre-checks should pass again).
- **Estimated rollback time:** `<N>` — must be ≤ RTO from §1.

## 9. Backups & Snapshots

- **What is backed up:** `<datasets/volumes/configs>`.
- **When:** immediately before the first destructive step in §5.
- **How:** `<command>`; **where it lands:** `<location>`.
- **Restore-tested:** `<yes/no — link the test>`. An untested backup is not a backup.
- **Retention:** keep until post-migration verification (§12) passes plus `<N>` days.

## 10. Comms Plan

- **Before:** who is notified, what channel, how far ahead.
- **During:** status cadence and where (e.g. an incident channel), who runs comms.
- **Decision owner:** the single person who calls go / no-go / abort.
- **After:** success/rollback notification and audience.

## 11. Post-Migration Verification

The system is not "done" until these pass on the live target:
- [ ] Functional smoke test of the migrated path.
- [ ] Data parity confirmed (counts, checksums, spot-checked records).
- [ ] Metrics/SLOs within budget for `<observation window>`.
- [ ] No elevated error rate vs the pre-migration baseline.
- [ ] Downstream consumers confirmed healthy.

## 12. Cleanup

Only after §11 passes and the rollback window has closed:
- [ ] Remove dual-write / shadow code.
- [ ] Drop deprecated columns/tables/old store (this is itself often a ⛔ point of no return —
      snapshot first, gate behind a final go/no-go).
- [ ] Retire feature flags and kill switches.
- [ ] Decommission old infrastructure.
- [ ] Update docs/diagrams; close the migration ticket.
