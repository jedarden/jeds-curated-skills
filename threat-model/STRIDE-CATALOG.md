# STRIDE Catalog

The six STRIDE categories. Each violates one security property. Walk EVERY data-flow element
— external entity, process, data store, and the flows between them — through all six. For each
element, ask the probing questions. A "no threat here" answer is valid only when stated and
justified, not when skipped.

---

## S — Spoofing

**Definition:** An attacker pretends to be someone or something else — a user, a service, a
device, a process.

**Property violated:** Authenticity.

**Example threats:**
- Stolen or guessed credentials used to log in as a legitimate user.
- A rogue service impersonating a trusted upstream (e.g., a fake auth server).
- Session token replay or fixation.
- Forged source identity on an unauthenticated message or webhook.

**Probing questions per element:**
- How is the identity of each side of this flow established?
- Can an attacker present a credential, token, or address that isn't theirs?
- Is mutual authentication required, or only one direction?
- What stops replay of a captured authentication artifact?

---

## T — Tampering

**Definition:** An attacker modifies data in transit, at rest, or in memory.

**Property violated:** Integrity.

**Example threats:**
- Modifying request parameters to change authorization or pricing.
- Altering records in a data store an attacker reached through another flaw.
- Man-in-the-middle rewriting of an unencrypted flow.
- Cache or configuration poisoning.

**Probing questions per element:**
- Can the payload of this flow be modified undetected in transit?
- Is data at rest protected from modification, and is modification detectable?
- Are integrity checks (signatures, MACs, checksums) applied where it matters?
- Can a client tamper with values the server trusts (hidden fields, client-set IDs)?

---

## R — Repudiation

**Definition:** An attacker (or user) performs an action and later denies it, and the system
cannot prove otherwise.

**Property violated:** Non-repudiation.

**Example threats:**
- A user disputes a transaction and there is no signed/timestamped record.
- An admin performs a destructive action with no audit trail.
- Logs are missing, mutable, or attributable to no actor.

**Probing questions per element:**
- Is every security-relevant action logged with actor, timestamp, and outcome?
- Are logs tamper-evident and protected from the actors they record?
- Can an action be traced to a single authenticated identity?
- What is explicitly NOT logged, and is that documented (e.g., secret values)?

---

## I — Information Disclosure

**Definition:** An attacker reads data they are not authorized to see.

**Property violated:** Confidentiality.

**Example threats:**
- Sensitive data sent over an unencrypted channel.
- Verbose errors or stack traces leaking internals.
- Overly broad API responses returning fields the caller shouldn't see.
- Secrets in logs, source, or client-visible config.
- Side channels: timing, enumeration, predictable identifiers.

**Probing questions per element:**
- Is data in transit and at rest encrypted commensurate with its sensitivity?
- Does this element return more than the caller is authorized to receive?
- Could error messages, logs, or metadata leak sensitive information?
- Are identifiers unguessable where enumeration would disclose data?

---

## D — Denial of Service

**Definition:** An attacker degrades or denies availability to legitimate users.

**Property violated:** Availability.

**Example threats:**
- Unauthenticated endpoints flooded with requests.
- Expensive operations triggered by cheap input (algorithmic complexity, unbounded queries).
- Resource exhaustion: connections, memory, disk, file handles.
- A single dependency outage cascading into total failure.

**Probing questions per element:**
- Is this element rate-limited and quota-bounded?
- Can cheap input force expensive work (amplification)?
- Are resources (connections, memory, payload size) bounded?
- What happens to the system when this element's dependency is slow or down?

---

## E — Elevation of Privilege

**Definition:** An attacker gains capabilities they are not entitled to.

**Property violated:** Authorization.

**Example threats:**
- Missing or broken access-control check lets a user act as admin.
- IDOR: accessing another tenant's object by changing an identifier.
- Injection (SQL, command, template) executing attacker-controlled logic.
- Privilege confusion across a trust boundary (client-trusted role claims).

**Probing questions per element:**
- Is every action authorized on the server, for the specific object, every time?
- Can a lower-privileged actor reach a higher-privileged capability?
- Are object references checked against the caller's ownership/tenant?
- Does input ever cross into a code/query interpreter without strict separation?

---

## Applying the Catalog

For every element in the data-flow inventory, produce one threat-table row per applicable
STRIDE category (six considered, fewer may apply). Each row gets a likelihood, an impact, a
mitigation (see `references/MITIGATION-LIBRARY.md`), and a residual-risk status. Elements that
cross a trust boundary deserve the most scrutiny — that is where attackers operate.
