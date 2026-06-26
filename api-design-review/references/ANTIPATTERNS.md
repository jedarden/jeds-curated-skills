# API Anti-Patterns Catalog

The reviewer matches findings against this catalog and names the anti-pattern in the report.
Each entry: what it looks like, why it bites, and the fix.

## A1 — Verbs in Paths (RPC-over-REST)
**Looks like:** `/createOrder`, `/getUser?id=5`, `/orders/delete`, `/doPayment`.
**Why it bites:** Duplicates HTTP method semantics into the path, breaks caching and tooling,
multiplies endpoints per resource, and resists consistent client generation.
**Fix:** Resource is the noun, action is the method: `POST /orders`, `GET /users/{id}`,
`DELETE /orders/{id}`. (gRPC RPCs may be verbs; their messages must stay nouns.)

## A2 — 200 OK With an Error Body
**Looks like:** `HTTP 200` + `{ "success": false, "error": "..." }` on failure.
**Why it bites:** Every client must parse the body to learn it failed; proxies, retries,
caches, and monitoring all treat it as success. The single most common contract defect.
**Fix:** Use real status codes — 4xx for client error, 5xx for server error — with a
consistent error envelope. The status line is the first source of truth.

## A3 — Unbounded List Endpoints
**Looks like:** `GET /events` returns all rows, no `limit`, no cursor.
**Why it bites:** Works in dev with 10 rows, melts in production at 10 million; unpredictable
latency and memory; no way to add pagination later without breaking clients.
**Fix:** Paginate every collection from day one (cursor preferred); document and enforce a
max page size.

## A4 — Leaking Internal Identifiers
**Looks like:** Auto-increment integer IDs in URLs, DB primary keys, internal enum ints,
sequential invoice numbers.
**Why it bites:** Enables enumeration/IDOR, leaks business volume, and couples the public
contract to the storage schema so you can't change the DB without changing the API.
**Fix:** Expose opaque, stable identifiers (UUID/slug) and enforce object-level authorization
regardless of ID guessability.

## A5 — Breaking Change Without a Version Bump
**Looks like:** Renaming a field, removing one, tightening a type, or changing a status code
on an existing endpoint with no version signal.
**Why it bites:** Silently breaks every deployed client's deserializer; you discover it from
the support queue, not a test.
**Fix:** Additive-only evolution; new optional fields; deprecate-then-remove with `Sunset`;
a schema-diff/contract test that blocks accidental breaks.

## A6 — Chatty Endpoints (N+1 by Design)
**Looks like:** To render one screen a client must call `/order`, then `/order/{id}/items`,
then `/items/{id}/product` per item.
**Why it bites:** Latency multiplies, mobile/edge clients suffer, the API gets blamed for
slowness that is structural.
**Fix:** Offer expansion/embedding (`?expand=items.product`), field selection, or a
purpose-built aggregate resource; for GraphQL, ensure the schema lets one query fetch the graph.

## A7 — Inconsistent Conventions Across the Surface
**Looks like:** `firstName` here, `last_name` there; `/user` and `/orders`; errors shaped
differently per endpoint; dates as epoch in one place and ISO in another.
**Why it bites:** Every client writes per-endpoint special cases; codegen and SDKs fight the
inconsistency; onboarding is slow.
**Fix:** One casing, one error envelope, one date/money format, one pagination grammar —
everywhere.

## A8 — Booleans That Should Have Been Enums
**Looks like:** `is_active`, then later `is_archived`, then `is_pending` — a combinatorial
explosion of flags for what is really one state field.
**Why it bites:** Illegal combinations become representable; adding a state means adding a
boolean and updating every client's logic.
**Fix:** Model mutually-exclusive states as a single typed enum (`status`) with documented
members and forward-compatible unknown-value handling.

## A9 — Floats for Money
**Looks like:** `"amount": 19.99` as an IEEE float.
**Why it bites:** Rounding errors, currency ambiguity, and reconciliation bugs.
**Fix:** Integer minor units (cents) or a decimal string, always paired with an explicit
currency code.

## A10 — Sensitive Data in URLs
**Looks like:** `?token=...`, `?password=...`, `?ssn=...`, API key in the path.
**Why it bites:** Lands in access logs, proxy logs, browser history, and referer headers.
**Fix:** Credentials and PII go in headers or the request body over TLS, never the URL.

## A11 — Null/Absent/Empty Ambiguity
**Looks like:** `[]` sometimes, `null` other times for an empty list; optional objects
sometimes omitted, sometimes `null`.
**Why it bites:** Strict clients crash; every consumer guesses; adding a field becomes risky.
**Fix:** Define and enforce: empty collections are `[]`; pick one rule for absent optionals
and hold it API-wide.

## A12 — Non-Idempotent Writes Without Idempotency Keys
**Looks like:** `POST /charges` with no `Idempotency-Key`; a network timeout on retry creates
a second charge.
**Why it bites:** Duplicate orders, double charges, duplicate records — the classic
at-least-once-delivery failure.
**Fix:** Accept and honor an idempotency key on unsafe creates; make PUT/DELETE idempotent by
design.

## A13 — Tunneling Everything Through POST
**Looks like:** Every operation is `POST`, including reads, with the real intent in the body.
**Why it bites:** Loses caching, safe-method guarantees, and semantic clarity; tooling can't
reason about it.
**Fix:** Use the method that matches the semantics; reserve POST for non-idempotent creates
and true actions.
