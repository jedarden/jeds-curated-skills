# Checklist 04 — Errors, Pagination, Filtering & Formats

Payload conventions must be uniform across the whole surface. Inconsistency here forces every
client to write per-endpoint special cases.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **4.1 Consistent Error Envelope**
  Every error returns the same shape (e.g. `{ "error": { "code", "message", "details" } }` or
  RFC 7807 `application/problem+json`). One envelope, used everywhere — not ad-hoc per endpoint.

- [ ] **4.2 Machine-Readable Error Codes**
  Errors carry a stable, documented, enumerable `code` string (`ORDER_NOT_FOUND`) that clients
  branch on — not just a human prose `message` that changes with copy edits.

- [ ] **4.3 Field-Level Validation Errors**
  Validation failures identify *which* field failed and why, in a structured list, so clients
  can map errors back to form fields without parsing prose.

- [ ] **4.4 Pagination on All Collections**
  Every list endpoint paginates. Strategy is explicit and consistent — cursor-based preferred
  for large/changing sets; offset/limit acceptable for small, stable sets and documented as such.
  No unbounded "return everything" list (see Anti-Patterns).

- [ ] **4.5 Pagination Metadata**
  Responses include what the client needs to continue: `next_cursor`/`has_more` (cursor) or
  total/limit/offset (offset). Page links or cursors are opaque and stable.

- [ ] **4.6 Filtering & Sorting Conventions**
  Filtering and sorting use one consistent grammar across collections (`?status=open&sort=-created_at`),
  documented, not a different scheme per endpoint. Allowed filter/sort fields are enumerated.

- [ ] **4.7 Field Selection / Sparse Responses**
  For wide resources, a way to request a subset of fields (sparse fieldsets, GraphQL selection,
  `?fields=`) exists or is consciously declined — to avoid forcing chatty over-fetching.

- [ ] **4.8 Consistent Scalar Formats**
  Dates/times are one format throughout (RFC 3339 / ISO 8601 UTC); money is integer minor units
  or decimal-string + currency code (never float); durations, IDs, and booleans are uniform.

- [ ] **4.9 Enums Over Free Text**
  Closed value sets are typed enums with documented members, not free-form strings clients must
  guess at. Enum casing is consistent.

- [ ] **4.10 Request Size & Collection Limits**
  Maximum request body size, maximum page size, and maximum batch size are defined and enforced,
  with a clear error when exceeded — not left unbounded.

- [ ] **4.11 Null/Empty Representation Consistency**
  Empty collections return `[]` not `null`; absent optional objects are consistently `null` or
  omitted (per 03.6), the same way across the whole API.
