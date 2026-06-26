# Runbook: Zero-Downtime Schema Change (Expand-Contract)

The recipe for changing a database schema while the application keeps serving traffic, with
no downtime and a clean abort at every phase but the last. This is the expand-contract pattern
made concrete. Use it whenever a column/table/constraint must change under a live application.

The core rule: **the schema and the application are never assumed to deploy atomically.** Old
and new code run simultaneously during every rollout, so every intermediate state must be valid
for both. You get there by making only additive changes until the very end.

---

## Worked Example

Rename `users.fullname` (a single column) into `users.first_name` + `users.last_name`,
zero downtime, with abort possible until the final drop.

---

## Phase 1 — Expand: Add the New Shape (Nullable)

- **Action:** `ALTER TABLE users ADD COLUMN first_name TEXT NULL, ADD COLUMN last_name TEXT NULL;`
- **Verify:** new columns exist and are nullable; existing reads/writes unaffected
  (`SELECT count(*) FROM users WHERE first_name IS NULL` returns all rows).
- **Rollback:** `ALTER TABLE users DROP COLUMN first_name, DROP COLUMN last_name;` — fully
  reversible; no app code depends on the new columns yet.

Additive and invisible to the running app. New columns MUST be nullable (or have a default) so
existing INSERTs that don't mention them keep working.

## Phase 2 — Dual-Write: Write Both Old and New

- **Action:** Deploy app code that writes `fullname` AND populates `first_name`/`last_name` on
  every create/update. Reads still come from `fullname`.
- **Verify:** new rows have both old and new columns populated and consistent
  (spot-check recent writes; divergence count = 0).
- **Rollback:** redeploy the previous app version (writes only `fullname`); flip via feature
  flag if wired. New columns simply stop being updated — harmless.

Old and new code coexist here: old instances write only `fullname`, new instances write both —
both states are valid because reads still use `fullname`.

## Phase 3 — Backfill: Populate Historical Rows

- **Action:** Batched, idempotent backfill of rows where the new columns are still null:
  `UPDATE users SET first_name = split_part(fullname,' ',1),
   last_name = split_part(fullname,' ',2) WHERE first_name IS NULL LIMIT <batch>;`
  repeated until zero rows remain. Throttle to protect production load.
- **Verify:** `SELECT count(*) FROM users WHERE first_name IS NULL` → 0; parity/checksum of
  derived values matches `fullname` on a sample.
- **Rollback:** none needed — backfill only fills the new columns, which nothing reads yet.
  Safe to pause, resume, or re-run (idempotent by the `WHERE first_name IS NULL` guard).

## Phase 4 — Switch Reads: New Columns Become Authoritative

- **Action:** Deploy app code that READS from `first_name`/`last_name` instead of `fullname`.
  Keep dual-writing `fullname` for now.
- **Verify:** application functions correctly against new columns; error rate flat vs baseline;
  no rows surfacing null names. Run as a canary (small % first) if possible.
- **Rollback:** redeploy the read-from-`fullname` version (or flip the read flag). Because
  `fullname` is still being written in Phase 2/4, it is current and safe to fall back to.

This is the last fully reversible phase. After Phase 4 is stable for an observation window,
proceed — but everything below trends toward irreversible.

## Phase 5 — Stop Old Writes

- **Action:** Deploy app code that stops writing `fullname` (writes only the new columns).
- **Verify:** new writes no longer touch `fullname`; reads (now from new columns) still correct;
  error rate flat.
- **Rollback:** redeploy the dual-write version. ⚠️ `fullname` is now stale for any row written
  since this phase — rolling back reads to `fullname` would lose those updates. A short reverse
  backfill (`fullname` from the new columns) reconciles it. Snapshot before this phase.

## Phase 6 — Contract: Drop the Old Column

> ⛔ POINT OF NO RETURN — dropping `fullname` is irreversible; its data is gone. Last safe abort
> point is the start of Phase 6. Snapshot the table first and get explicit go/no-go.

- **Action:** after an observation window with reads on the new columns and old writes stopped:
  `ALTER TABLE users DROP COLUMN fullname;`
- **Verify:** column gone; application fully healthy on the new schema; post-migration checks pass.
- **Rollback:** snapshot restore only (see ROLLBACK-PATTERNS.md → Snapshot/Restore). There is no
  in-place undo. This is why the snapshot at Phase 5/6 is mandatory.

---

## Invariants (true at every phase boundary)

- The currently-running app — old AND new instances — is valid against the current schema.
- Every change up to Phase 6 is additive or behavioral, never destructive.
- A row is always readable through at least one authoritative column.
- The old column stays current and trustworthy until Phase 5; treat it as the rollback target
  for reads until then.
