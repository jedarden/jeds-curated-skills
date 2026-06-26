# Checklist 02 — Method Semantics & Status Codes

Clients, proxies, and caches rely on standard semantics. Violating them breaks retries,
caching, and tooling in ways that are invisible until production.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **2.1 Correct Method per Operation**
  Reads use GET, creates use POST, full replaces use PUT, partial updates use PATCH, deletes
  use DELETE. (gRPC/GraphQL equivalent: queries are read-only, mutations declared as such.)

- [ ] **2.2 Safe Methods Have No Side Effects**
  GET (and HEAD) never mutate state. No `GET /orders/{id}/delete`, no state change hidden
  behind a read. Safe methods are cacheable and prefetch-safe.

- [ ] **2.3 Idempotency Where Required**
  PUT and DELETE are idempotent — repeating the call yields the same end state. Non-idempotent
  creates (POST) provide an idempotency key mechanism (see 05) so retries don't duplicate.

- [ ] **2.4 Accurate Status Codes**
  2xx for success (201 + `Location` on create, 204 for empty success), 4xx for client error,
  5xx for server error. No 200 wrapping an error body (the cardinal sin — see Anti-Patterns).

- [ ] **2.5 Specific Error Codes**
  400 vs 401 vs 403 vs 404 vs 409 vs 422 vs 429 are distinguished correctly. Auth-missing is
  401, auth-present-but-forbidden is 403, validation failure is 422 (or documented 400).

- [ ] **2.6 Partial Update Semantics Defined**
  If PATCH exists, its semantics are explicit: JSON Merge Patch, JSON Patch, or a documented
  field-replace rule. Null vs absent field behavior is specified (see 03.6).

- [ ] **2.7 Content Negotiation**
  Content-Type and Accept are honored; the default representation is documented. JSON is the
  baseline; any alternate format (CSV, protobuf, msgpack) is opt-in via Accept, not a new path.

- [ ] **2.8 Conditional Requests / Concurrency Control**
  Mutable resources support optimistic concurrency: ETag + If-Match (or a version field) so
  concurrent writers get 412/409 instead of silently clobbering each other.

- [ ] **2.9 Bulk & Long-Running Operations**
  Batch operations and async/long-running jobs have a defined pattern (202 + status resource,
  or a batch envelope with per-item results), not an unbounded synchronous loop.

- [ ] **2.10 Method Override Not Required**
  The API does not rely on `X-HTTP-Method-Override` or tunneling everything through POST to
  work around client/proxy limitations.
