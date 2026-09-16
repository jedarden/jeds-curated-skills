# Self-Test: threat-model

Prose-only skill — two surfaces: coverage review (`CHECKLIST-COVERAGE.md`,
15 items across Enumeration / STRIDE walk / Mitigation & risk / Framing) and
author mode (TEMPLATE.md sections + a per-element six-category STRIDE walk).
The regression shape: a fixture model with a planted gap on most items and
three deliberately solid items, so a checklist edit that shifts what counts as
coverage shows up as a changed inventory.

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "write a threat model for this service" | Activates, author mode |
| "walk STRIDE on our architecture" | Activates, author mode |
| "audit our threat model for gaps" | Activates, review mode |
| "/threat-model review THREAT-MODEL.md" | Activates, review mode |
| "rotate the API keys" | Does NOT activate — remediation advice, not threat modeling |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
SKILL_DIR="$REPO/threat-model"
ls -1 "$SKILL_DIR"              # CHECKLIST-COVERAGE.md, STRIDE-CATALOG.md,
                                # TEMPLATE.md, SELF-TEST.md, SKILL.md,
                                # references/, subagents/
ls -1 "$SKILL_DIR/references"   # MITIGATION-LIBRARY.md, EXAMPLES.md
ls -1 "$SKILL_DIR/subagents"    # threat-modeler.md
```

## Review-mode fixture

A thin model with planted gaps (annotations inline; a real review sees them
without the comments):

````bash
T="$(mktemp -d)"
cat > "$T/THREAT-MODEL.md" <<'EOF'
# Threat model — Invoice API

## Assets

The system and its data. (planted: 1.1 vague — "the system" is not an asset)

## Trust boundaries

- Internet ↔ API gateway. (planted: 1.2 — the API ↔ Postgres boundary and the
  tenant ↔ tenant boundary are never named)

## External entities

- End users (browser), the Stripe webhook, the payment processor API.

## Data stores

- Postgres. (planted: 1.4 — the Redis session cache and the S3 invoice
  bucket are not enumerated)

## Data flows

- Users → API → Postgres. (planted: 1.5 — no direction/payload/boundary per
  flow)

## Entry points

- `POST /invoices`, `GET /invoices/{id}`. (planted: 1.6 — the Stripe webhook
  endpoint and the nightly batch importer are entry points but unlisted)

## Threats

| ID | Element | Category | Threat | Likelihood | Impact | Mitigation | Status |
|----|---------|----------|--------|------------|--------|------------|--------|
| T1 | POST /invoices | Spoofing | Forged session cookie | Low | High | Signed cookies, 15-min TTL | Mitigated |
| T2 | GET /invoices/{id} | Information disclosure | IDOR on invoice ids | Med | High | (blank — planted: 3.1 no mitigation) | (blank — planted: 3.2 no status) |
| T3 | API process | DoS | Unbounded query size | Med | Med | Request size cap | Mitigated |

(planted: 2.1 — no element is walked through all six categories and no
category is marked N/A with a reason; 2.2 — the internet-facing flow has no
Tampering or Information-disclosure analysis beyond T2; 2.3 — authorization
is "users are logged in", no per-object/tenant check anywhere)

## Assumptions

(none stated — planted: 4.1)

## Out of scope

(none declared — planted: 4.2)

## Diagram

```
[browser] --HTTPS--> [gateway] --> [api] --> [postgres]
```
EOF
echo "$T" > /tmp/tm-selftest-dir
```

**Expected inventory — `/threat-model review <fixture>`:**

| Item | Rating | Because (the planted defect) |
|------|--------|------------------------------|
| 1.1 Assets | MISSING | "The system and its data" — vague |
| 1.2 Trust boundaries | PARTIAL | Internet↔gateway only; app↔db and tenant↔tenant absent |
| 1.3 External entities | PRESENT | Users, Stripe webhook, processor API |
| 1.4 Data stores | PARTIAL | Postgres only; Redis cache and S3 bucket missing |
| 1.5 Data flows | PARTIAL | Listed without direction/payload/boundary |
| 1.6 Entry points | PARTIAL | HTTP routes only; webhook + batch importer unlisted |
| 2.1 Per-element STRIDE | PARTIAL | Some elements have some categories; no six-category walk, no N/A reasons |
| 2.2 Boundary-crossing focus | MISSING | Internet flow lacks Spoofing/Tampering/Disclosure treatment |
| 2.3 Authorization per object | MISSING | "logged in" only — IDOR/tenant confusion unexamined |
| 3.1 Mitigation per threat | MISSING | T2's mitigation cell is blank |
| 3.2 Residual-risk status | PARTIAL | T2's status blank; others have it |
| 3.3 Likelihood and impact | PRESENT | Every row rated |
| 4.1 Assumptions stated | MISSING | Empty section |
| 4.2 Out-of-scope declared | MISSING | Empty section |
| 4.3 Diagram / structured inventory | PRESENT | Text diagram present |

Hard pins: **3 PRESENT / 6 PARTIAL / 6 MISSING**; 1.1 MISSING (vague-asset
rule is verbatim in the checklist); 3.1 flagged on the blank T2 cell; 2.3
called out as the IDOR blind spot. The report must open with the scorecard,
order critical gaps by priority (un-walked elements and un-mitigated
high-impact threats first), name 3–5 genuine strengths (here: T1's concrete
mitigation, the likelihood/impact ratings, the diagram), and close with top-5
next steps. Then it offers the fix pass scoped to MISSING/PARTIAL only.

## Author-mode checks

Fixture input — a tiny architecture doc with exactly the surfaces a model
must catch:

```bash
T="$(cat /tmp/tm-selftest-dir)"
cat > "$T/ARCHITECTURE.md" <<'EOF'
# Widgetline Sync — architecture

A service that syncs widget catalogs from tenant-supplied webhook events.

- Public HTTPS endpoint `POST /webhooks/tenant-events`, authenticated by a
  per-tenant static token in a header.
- Events are queued in Redis, consumed by a worker, written to Postgres
  (multi-tenant, single schema, tenant_id column).
- Nightly batch job pulls vendor price lists over SFTP and upserts them.
- Admins manage tenants through an internal UI on the private network.
EOF
```

**Expected** (`/threat-model author <fixture>`): `THREAT-MODEL.md` written
next to the input, containing all TEMPLATE.md sections — system overview,
assets, trust boundary diagram, data flow inventory, threat table with the
full column set (ID / element / STRIDE category / threat / likelihood /
impact / mitigation / status), mitigations, residual risks, assumptions.

Mechanical pins on the table:

- Every entry point from the doc appears as an element: the webhook, the SFTP
  pull, the admin UI, the Redis consume.
- The per-tenant static token draws an explicit **Spoofing** threat (token
  theft/reuse) — the single most load-bearing catch in this fixture; a model
  that misses it failed to read the input.
- All six STRIDE categories appear across the table, and any category skipped
  for an element carries a stated N/A reason (CHECKLIST-COVERAGE 2.1).
- Elevation-of-privilege analysis covers **per-object/tenant** authorization
  (the tenant_id column is cross-tenant data), not just login (2.3).
- Mitigations come from references/MITIGATION-LIBRARY.md keyed by category —
  e.g. webhook: HMAC signature or mTLS over static bearer tokens; SFTP:
  host-key pinning + credential scoping.
- Every row has mitigation and status filled — the blank-cell defect the
  review fixture plants cannot exist in a freshly authored model.

## Expected Behaviors

- **Mode inference**: a file already containing a threat table or STRIDE
  analysis ⇒ review; an architecture/design doc ⇒ author; ambiguous ⇒
  AskUserQuestion.
- **Input location is autonomous**: scans for THREAT-MODEL.md (review) or
  ARCHITECTURE.md/design/plan/README (author); falls back to grep for entry
  points; multiple candidates ⇒ ask, never guess.
- **"Enumerated but not walked" is the headline failure**: a model listing
  ten threats but never naming its trust boundaries reads as incomplete, not
  thorough — the review says so.
- **Fix pass is scoped**: re-spawns the modeler for MISSING/PARTIAL elements
  only, inserting rows into the existing document (prioritizing un-walked
  elements and un-mitigated high-impact threats), after the user accepts.
