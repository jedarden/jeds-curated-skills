# Checklist 04 — Security

Flag ONLY where a vulnerability is clearly present in the changed code — not theoretical, not
"could be hardened." Rate each: does the diff satisfy the criterion — PASS / CONCERN / FAIL.
When in doubt, do not flag; the verifier will drop weakly-grounded items anyway.

- [ ] **4.1 Injection**
  User-controlled input flows into a SQL query, shell command, eval, template, or other
  interpreter via string concatenation rather than parameterization/escaping.

- [ ] **4.2 Unvalidated / Untrusted Input**
  External input crosses a trust boundary without validation, bounds checks, or sanitization
  before being used in a sensitive operation.

- [ ] **4.3 Secrets in Code**
  Credentials, API keys, tokens, or private keys are hardcoded or logged in plaintext by the
  diff. No secret committed in a literal or fixture.

- [ ] **4.4 Authorization Checks**
  A new endpoint, action, or resource access enforces the authz/ownership check its peers do.
  No privileged operation reachable without the gate.

- [ ] **4.5 Unsafe Deserialization**
  Untrusted data is deserialized with a mechanism that can instantiate arbitrary types or execute
  code (pickle, native object deserializers, unsafe YAML).

- [ ] **4.6 Path Traversal**
  User-supplied path components are joined into filesystem or URL paths without normalization and
  containment to an allowed root, enabling `../` escape.

- [ ] **4.7 Sensitive Data Exposure**
  The diff does not widen what is returned, logged, or serialized to include secrets, PII, or
  internal data that the prior code withheld.
