# Migration Patterns

Pick the pattern that fits the From→To and downtime tolerance. Patterns compose — a typical
zero-downtime store migration is expand-contract on the schema plus dual-write+backfill on the
data plus canary on the reads. For each pattern: when to use it, and its rollback story (the
single most important property — a pattern with no clean rollback is not a safe pattern).

---

## Expand-Contract (Parallel Change)

**What:** Make a change in additive phases so old and new coexist. Expand (add the new shape,
keep the old), migrate readers/writers across, then contract (remove the old shape). The full
recipe for schema changes is in `runbooks/ZERO-DOWNTIME.md`.

**When:** Schema changes that must happen with zero downtime — adding/renaming/retyping a
column, splitting a table, changing a constraint. The default for database migrations.

**Rollback story:** Excellent while expanding — every phase before "contract" is additive and
reversible by simply not advancing. The contract phase is the point of no return; gate it
behind a go/no-go and snapshot first.

---

## Dual-Write + Backfill

**What:** Write to both the old and new store simultaneously for new data, while a background
job backfills historical data into the new store. Once parity is reached and verified, switch
reads to the new store, then stop writing to the old one.

**When:** Moving a dataset to a new database/store while serving live traffic; you cannot
afford a freeze long enough to copy everything at once.

**Rollback story:** Strong until reads are cut over — the old store stays authoritative and
fully current, so you abort by flipping reads back and dropping the new store. After old
writes stop, the old store goes stale; rolling back then needs a reverse backfill.

---

## Shadow / Read-Compare

**What:** Send production traffic to the new path in parallel with the old, but discard the new
path's results — instead compare them against the old path's results and log divergences. The
old path remains authoritative throughout.

**When:** Validating a new service, query engine, or computation against the trusted old one
before letting it serve real responses. De-risks a cutover by proving equivalence under real load.

**Rollback story:** Trivial — the shadow path never affects users, so "rollback" is just turning
the shadow off. Its job is to earn confidence before you adopt a riskier cutover pattern.

---

## Blue-Green

**What:** Stand up a complete second environment (green) alongside the live one (blue), migrate
and warm it, then switch all traffic from blue to green at once (load balancer / DNS / router).
Keep blue intact and idle as the instant fallback.

**When:** Whole-environment cutovers — a new cluster, a major version, an infra move — where you
want an atomic switch and an instant shift-back, and can afford running two environments briefly.

**Rollback story:** Best-in-class for the cutover itself — shift traffic back to blue instantly.
Caveat: any state written to green after the switch (orders, writes) must be reconciled back to
blue, so pair with dual-write for stateful systems or the shift-back loses data.

---

## Canary

**What:** Shift a small fraction of traffic (1% → 5% → 25% → 100%) to the new path, watching
error rate and latency at each step, with automated abort if a gate fails. Advance only when
the current slice is healthy.

**When:** Service-to-service cutovers and risky rollouts where blast radius must be capped and
problems caught while they affect few users.

**Rollback story:** Excellent and graduated — at any percentage, shift the slice back to the old
path; only the canary fraction was ever exposed. Define the abort thresholds before you start.

---

## Strangler-Fig

**What:** Incrementally replace a legacy system by routing one capability/endpoint at a time to
the new implementation behind a façade, until the old system is fully encircled and can be
retired. The legacy system keeps serving everything not yet migrated.

**When:** Large legacy migrations too risky to cut over wholesale — migrate API-by-API or
feature-by-feature over weeks/months.

**Rollback story:** Good and localized — each routed capability is an independent switch you can
flip back without touching the others, so rollback is scoped to a single endpoint, not the whole
system. Retiring the legacy system at the end is the point of no return.
