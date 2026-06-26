# Rollback Patterns

The mechanics of undo. Every migration needs at least one of these wired and tested *before*
the first irreversible step. Each entry: what it is, when it applies, and its trade-offs (every
rollback mechanism has a cost — pretending otherwise is how rollbacks fail under pressure).

---

## Snapshot / Restore

**What:** Take a point-in-time snapshot (DB dump, volume snapshot, table copy) before the
destructive step; on abort, restore from it.

**When:** The universal fallback for any data-mutating or destructive step — and mandatory
before any point-of-no-return.

**Trade-offs:** Restore loses everything written between the snapshot and the abort (bounded by
your RPO), and restore time may be long for large datasets (must fit within RTO). The snapshot
is worthless unless its restore has been tested — an untested snapshot is not a rollback.

---

## Feature-Flag Kill Switch

**What:** Guard the new behavior behind a flag; rollback is flipping the flag off, with no
deploy and no data change.

**When:** Code-path cutovers, dual-write toggles, canary read-switches — anywhere the new
behavior can be toggled at runtime.

**Trade-offs:** Fastest possible rollback (seconds) and no data loss, but only covers behavior
gated by the flag — it cannot undo data already written by the new path. The flag plumbing must
exist and be tested before cutover; a flag you've never flipped is a liability.

---

## Reverse Migration

**What:** A second migration script that inverts the forward one (drop the added column, move
data back, restore the old constraint).

**When:** Schema and data migrations where a clean inverse exists; the standard "down" migration
in expand-contract before the contract phase.

**Trade-offs:** Clean and scriptable for additive changes, but genuinely irreversible operations
(a dropped column's data, a lossy type narrowing) have no inverse — the reverse migration
recreates the structure, not the lost data. Write and test the down-migration alongside the up.

---

## Version Pinning

**What:** Pin the exact prior version (image digest, package version, config revision) so
rollback is redeploying the known-good artifact.

**When:** Service/infra cutovers and dependency upgrades; the rollback half of blue-green.

**Trade-offs:** Reliable and fast for stateless components, but does nothing for state — if the
new version migrated data forward, redeploying the old binary against the new schema can break
worse than staying. Pin code rollback to a schema rollback for stateful services.

---

## Traffic Shift-Back

**What:** Move traffic back to the old path at the router/load-balancer/DNS layer (the rollback
half of canary and blue-green).

**When:** Any cutover fronted by a traffic director where the old path is still live and current.

**Trade-offs:** Near-instant for load-balancer/router shifts; DNS shifts are throttled by TTL,
so set a low TTL *before* the migration or the shift-back lags. Only safe while the old path is
still authoritative and up to date — once it goes stale, shift-back loses the delta. Reconcile
any state written during the cutover.
