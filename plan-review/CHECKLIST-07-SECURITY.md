# Checklist 07 — Security

Security gaps found mid-implementation are expensive. Post-ship is worse.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **7.1 Threat Model**
  Named threats with: who is the attacker, what is the attack surface, what is the impact.
  "Internal tool, no external threats" is a valid explicit statement — but must be stated.

- [ ] **7.2 Secrets Handling**
  How secrets (API keys, tokens, credentials) are:
  - Stored
  - Never logged (explicit policy)
  - Rotated

- [ ] **7.3 Audit Logging**
  What events are logged for security or compliance purposes.
  What events are explicitly NOT logged (e.g., secret values).

- [ ] **7.4 Untrusted Input Policy**
  How input from external sources (users, files, network) is validated and sanitized.
  Stated as a blanket policy, not left to individual components.

- [ ] **7.5 Supply Chain Considerations**
  For systems that process or distribute code/packages:
  dependency pinning, checksum verification, update policy.

- [ ] **7.6 Per-Threat Security Matrix**
  For security-sensitive systems: table mapping
  threat → attack vector → mitigation → test.
  Required when threat model identifies more than 3 threats.
