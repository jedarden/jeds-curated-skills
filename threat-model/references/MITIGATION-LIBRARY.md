# Mitigation Library

Common mitigations keyed by STRIDE category. Pick from these, then make each one specific to
the element it protects — name the actual endpoint, store, or flow. A mitigation that doesn't
say where it lives is not actionable.

---

## Spoofing → strengthen authentication

- Strong authentication: salted+hashed passwords, breached-password screening.
- Multi-factor authentication (TOTP, WebAuthn) for high-value accounts and admin access.
- Mutual TLS or signed requests between services.
- Verify webhook/callback authenticity (HMAC signature, shared secret).
- Short-lived, audience-scoped tokens; bind sessions to device/IP where feasible.
- Anti-replay: nonces, timestamps, one-time tokens.

## Tampering → enforce integrity

- TLS for all data in transit; reject downgrade (HSTS).
- Sign or MAC messages whose integrity matters (JWT with verified signature, signed cookies).
- Never trust client-supplied values that drive authorization or pricing — re-derive server-side.
- Checksums / content hashes for stored artifacts and uploads.
- Database constraints and optimistic concurrency to detect conflicting writes.
- Immutable / append-only stores for records that must not change.

## Repudiation → make actions provable

- Audit log of security-relevant actions: actor, action, object, timestamp, outcome.
- Tamper-evident logging (append-only sink, write to a store the actor cannot edit).
- Tie every action to a single authenticated identity.
- Explicitly exclude secret values from logs (and document the exclusion).
- Retain logs long enough to investigate disputes.

## Information disclosure → enforce confidentiality

- Encrypt sensitive data at rest and in transit.
- Authorize and field-filter API responses — return only what the caller may see.
- Generic error messages externally; detailed errors only in internal logs.
- Unguessable identifiers (UUIDs) where enumeration would disclose data.
- Keep secrets out of source, client bundles, and logs; use a secret store.
- Mitigate side channels: constant-time comparisons, uniform error/timing on auth paths.

## Denial of service → protect availability

- Rate limiting and quotas per IP and per account, especially on unauthenticated endpoints.
- Bound expensive work: pagination, max page/payload size, query timeouts.
- Resource limits: connection pools, memory caps, request size limits, upload limits.
- Backpressure, circuit breakers, and timeouts on outbound dependencies.
- Caching and CDN for read-heavy paths; autoscaling within bounds.
- Reject algorithmically-expensive input (regex/parse bombs, deep nesting).

## Elevation of privilege → enforce authorization

- Authorize every action on the server, for the specific object, every time.
- Per-object / per-tenant ownership checks (defeats IDOR) at the data-access layer.
- Least privilege for service accounts, DB roles, and API scopes.
- Parameterized queries / prepared statements; no string-built SQL or shell.
- Strict separation of code and data: no `eval`, safe templating, allowlist deserialization.
- Server-side role/permission source of truth — never trust client-asserted roles.
