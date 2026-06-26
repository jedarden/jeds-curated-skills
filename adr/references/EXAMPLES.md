# ADR Examples — One Strong, One Weak

Calibration material. The strong ADR shows the bar. The weak ADR is annotated with exactly what is
wrong so a reviewer can recognize the same failures in the wild.

---

## STRONG — worked example

# 0008. Use cursor-based pagination for the public list API

- **Status:** Accepted
- **Date:** 2026-02-14
- **Deciders:** API platform team

## Context

The public `GET /v1/events` endpoint returns a list that grows continuously; new events are inserted
at the head many times per second. Clients page through results to build local mirrors and to render
infinite-scroll UIs.

Forces at play:
- **Correctness under writes:** rows are inserted between client page requests. Skipping or
  duplicating rows during a scroll corrupts client mirrors.
- **Performance at depth:** some clients page tens of thousands of rows deep on every sync.
- **Stateless servers:** the API tier is horizontally autoscaled; we cannot pin a client to a server
  or hold per-client cursors in memory.
- **Stable public contract:** once shipped, the pagination shape is hard to change without breaking
  every integrator.

## Decision

We will use cursor-based (keyset) pagination. Each response includes an opaque `next_cursor`
encoding the last row's `(created_at, id)` tuple; the next request passes it back as `?after=`.
The server translates it to `WHERE (created_at, id) > (:ts, :id) ORDER BY created_at, id LIMIT n`.

## Considered Alternatives

### Offset/limit pagination (`?offset=&limit=`)
- **Pros:** trivial to implement; lets clients jump to an arbitrary page; universally understood;
  no cursor encoding to maintain.
- **Cons:** inserts at the head shift every row's offset, so a concurrent scroll skips or repeats
  rows; `OFFSET 50000` forces the database to scan and discard 50k rows on every deep page.
- **Why not:** fails the "correctness under writes" and "performance at depth" forces directly —
  the two hardest constraints here.

### Snapshot pagination (materialize the result set per client, page over the snapshot)
- **Pros:** perfectly stable view for the duration of a scroll; clean semantics; immune to
  concurrent writes.
- **Cons:** requires per-client server-side state (a temp table or cached result set) with a TTL
  and eviction policy.
- **Why not:** violates the "stateless servers" force — our autoscaled tier has nowhere durable to
  hold per-client snapshots, and adding a shared store is more machinery than the problem warrants.

## Consequences

- **Positive:** stable iteration under concurrent inserts; constant-time deep paging (an index seek,
  not a scan); no server-side per-client state.
- **Negative:** clients can no longer jump to "page 500" — only forward/backward from a cursor; total
  count is no longer cheap to expose alongside pages; the cursor is opaque, so debugging a client's
  position requires decoding it. Sorting is fixed to `(created_at, id)` — adding user-selectable sort
  orders later means minting new cursor formats.
- **Follow-on work:** add a composite index on `(created_at, id)`; document cursor opacity for
  integrators; provide a separate `/count` endpoint for clients that need totals.

## Reversibility / Cost to Change

- **Blast radius:** the response shape is part of a public contract; reverting to offsets after
  launch breaks every integrator's paging loop.
- **Type:** one-way door once shipped publicly. Cheap to revisit while still in beta.
- **Reversal trigger:** if clients overwhelmingly need random page access and give up live-mirror
  correctness, reconsider — unlikely given the sync use case.

---

## WEAK — annotated example

# 12. Database

> **[1.1 FAIL]** Title is a topic, not a decision. "Database" tells the reader nothing about the verdict.

- **Status:** —

> **[1.2 / 1.3 FAIL]** No status, no date. Lifecycle and staleness are invisible.

## Context

We need a database. We chose PostgreSQL because it is the best database.

> **[1.4 FAIL]** Context states the choice, not the forces. No constraints (scale, consistency,
> query shape, team familiarity, ops budget). A reader learns nothing about why this was hard.

## Decision

Use Postgres.

> **[1.5 PARTIAL]** Directionally clear but not actionable — managed or self-hosted? which version?
> what is it storing? No mechanism.

## Considered Alternatives

- MongoDB — not relational, so no.
- A flat file — obviously won't scale.

> **[1.6 / 1.7 FAIL — STRAWMEN]** Two alternatives, neither steel-manned. MongoDB's actual strengths
> (flexible schema, horizontal sharding) go unmentioned; "not relational, so no" is not a reason.
> "A flat file" is a joke option padding the list. Zero alternatives were genuinely weighed.

## Consequences

- We get a reliable, powerful, battle-tested database. Great tooling. Easy to hire for.

> **[1.8 FAIL — NO NEGATIVES]** All upside. Nothing on operational burden, vertical-scaling ceiling,
> migration cost, or what becomes harder. Every real decision has a cost; this section hides it.

> **[1.9 / 1.10 MISSING]** No follow-on work, no reversibility note. If this needs to change later,
> nobody knows what it would cost or what would trigger it.
