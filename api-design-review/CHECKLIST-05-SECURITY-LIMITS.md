# Checklist 05 — Authn/Authz, Rate Limits & Input Safety

Security and abuse-control decisions are baked into the contract. Retrofitting auth scopes or
rate limits after launch breaks every existing client.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **5.1 Authentication Model Declared**
  How callers authenticate is explicit (OAuth2 bearer, mTLS, API key, session) and uniform.
  The scheme is named, the token format and transport (Authorization header) are specified.

- [ ] **5.2 Authorization Model & Scopes**
  Per-operation authorization is defined: scopes/roles/permissions are enumerated and each
  endpoint states what it requires. Not "auth is handled elsewhere."

- [ ] **5.3 No Sensitive Data in URLs**
  Tokens, passwords, API keys, PII, and secrets never appear in path or query strings (they
  land in logs, proxies, browser history). They go in headers or the body.

- [ ] **5.4 Rate Limiting + 429 + Retry-After**
  Rate limits are defined, return 429 when exceeded, and include `Retry-After` (and ideally
  `RateLimit-*` headers) so well-behaved clients can back off instead of hammering.

- [ ] **5.5 Idempotency Keys for Unsafe Writes**
  Non-idempotent writes (POST that creates/charges) accept an `Idempotency-Key` so a retried
  request after a timeout does not double-create or double-charge.

- [ ] **5.6 Input Validation Contract**
  Every input field has declared type, format, length/range bounds, and required/optional
  status. Validation is server-side and the spec is the source of truth (not client-only).

- [ ] **5.7 Object-Level Authorization (No IDOR)**
  Access to an item by ID is checked against the caller's ownership/permissions — guessing
  another tenant's `/orders/{id}` is rejected, not just obscured by an unguessable ID.

- [ ] **5.8 CORS / Cross-Origin Policy**
  For browser-exposed APIs, the CORS policy (allowed origins, methods, credentials) is
  explicit and least-privilege — not `Access-Control-Allow-Origin: *` with credentials.

- [ ] **5.9 No Sensitive Data Over-Exposure**
  Responses don't leak internal fields, secrets, password hashes, full PII, or stack traces.
  5xx errors return a generic message, not server internals.

- [ ] **5.10 Transport Security & Method Restrictions**
  TLS is required; state-changing operations are not reachable via GET; and abuse-prone
  endpoints (auth, search) have stricter limits documented.
