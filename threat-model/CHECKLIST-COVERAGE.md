# Checklist — Threat Model Coverage

A threat model is only as good as what it enumerated and walked. A model that lists ten
threats but never enumerated its trust boundaries is incomplete, not thorough.
Rate each: PRESENT / PARTIAL / MISSING

## Enumeration — did the model name everything in scope?

- [ ] **1.1 Assets / Crown Jewels**
  The data and capabilities worth protecting are named (e.g., user PII, credentials,
  payment data, the ability to issue refunds). Vague "the system" is not an asset.

- [ ] **1.2 Trust Boundaries**
  Every boundary where data crosses between differently-trusted zones is identified
  (internet ↔ app, app ↔ database, tenant ↔ tenant, user ↔ admin).

- [ ] **1.3 External Entities**
  All actors and external systems that interact with the system are listed (end users,
  admins, third-party APIs, webhooks, batch jobs).

- [ ] **1.4 Data Stores**
  Every place data rests is enumerated (databases, caches, object storage, queues, logs,
  config/secret stores).

- [ ] **1.5 Data Flows**
  The flows between entities, processes, and stores are inventoried, each with a direction,
  payload, and the trust boundary it crosses (if any).

- [ ] **1.6 Entry Points**
  Every way input enters the system is listed (HTTP routes, webhooks, message consumers,
  file uploads, CLI/admin interfaces, scheduled triggers).

## STRIDE Walk — was each element examined through all six categories?

- [ ] **2.1 Per-Element STRIDE Coverage**
  Each element (especially boundary-crossing flows and entry points) is walked through all
  six STRIDE categories, with a stated reason when a category does not apply.

- [ ] **2.2 Boundary-Crossing Focus**
  Flows that cross a trust boundary receive explicit Spoofing, Tampering, and Information
  disclosure analysis — not just the application's own processes.

- [ ] **2.3 Authorization Per Object**
  Elevation-of-privilege analysis checks per-object/per-tenant authorization, not only
  "is the user logged in" (catches IDOR and privilege confusion).

## Mitigation & Risk — does each threat lead somewhere?

- [ ] **3.1 Mitigation Per Threat**
  Every identified threat has a named mitigation (control, design change, or accepted-risk
  decision) — not a blank cell.

- [ ] **3.2 Residual-Risk Status**
  Each threat has a status (e.g., Mitigated / Partially mitigated / Accepted / Open) so the
  reader knows what is still exposed.

- [ ] **3.3 Likelihood and Impact**
  Each threat is rated for likelihood and impact, so prioritization is possible rather than
  a flat undifferentiated list.

## Framing — is the scope honest?

- [ ] **4.1 Assumptions Stated**
  The trust assumptions are explicit (e.g., "the database network is private,"
  "TLS terminates at the load balancer," "admins are trusted").

- [ ] **4.2 Out-of-Scope Declared**
  What the model deliberately does not cover is stated (e.g., physical security, insider
  threat, supply-chain) so gaps are intentional, not accidental.

- [ ] **4.3 Diagram or Structured Inventory**
  A trust-boundary diagram (text/mermaid) or equivalent structured inventory lets a reader
  reconstruct the system without reading the whole codebase.
