# Worked Mini Example

A small, self-contained example to calibrate what "walked through STRIDE" looks like. The
system is a generic notes web service: users sign in, create private notes, and the app stores
them in a relational database.

---

## System Shape

- **API service** — public HTTPS, exposes `POST /login`, `GET /notes`, `POST /notes`,
  `GET /notes/{id}`.
- **Database** — private network, stores users (with password hashes) and notes (each owned by
  a user).

## Trust Boundaries

- **TB1 — Internet ↔ API:** untrusted users reach the API.
- **TB2 — API ↔ Database:** the API reaches the private store.

## Assets

- A1: Users' private notes (confidential).
- A2: Password hashes (critical).

## Data Flow Inventory

| DF | From → To | Payload | Crosses | Entry point |
|----|-----------|---------|---------|-------------|
| DF1 | User → API | Credentials | TB1 | `POST /login` |
| DF2 | User → API | Note id | TB1 | `GET /notes/{id}` |
| DF3 | API → DB | Note records | TB2 | — |

## Sample Threat-Table Rows

These five rows show one threat per relevant STRIDE category, each ending in a concrete
mitigation and a status. A full model would walk every element this way.

| ID | Element | STRIDE | Threat | Likelihood | Impact | Mitigation | Status |
|----|---------|--------|--------|-----------|--------|------------|--------|
| T1 | DF1 (`POST /login`) | Spoofing | Credential stuffing using leaked passwords logs in as a victim | High | High | Per-account + per-IP rate limit, breached-password screening, optional TOTP MFA | Mitigated |
| T2 | DF2 (`GET /notes/{id}`) | Elevation of privilege | A user requests another user's note id (IDOR) and reads their private note | High | Critical | Data layer filters by `owner_id = session.user`; return 404 on mismatch | Mitigated |
| T3 | DF1 → DB | Information disclosure | Stored passwords readable if the DB is exfiltrated | Low | Critical | Store only Argon2id hashes; DB on private network, encrypted at rest | Mitigated |
| T4 | `GET /notes` | Denial of service | Unauthenticated/unbounded list query exhausts the DB | Medium | Medium | Require auth; paginate with a max page size; query timeout | Partial |
| T5 | API logging | Repudiation | A disputed deletion cannot be attributed to an actor | Medium | Medium | Audit log of writes with actor, action, note id, timestamp; exclude note bodies | Mitigated |

## How to Read This

- Every row names a **specific element**, not "the app."
- Each STRIDE category is anchored to the **probing question** it answers (T2 came from "can a
  lower-privileged actor reach a higher-privileged capability — per object?").
- Every threat ends in a **mitigation** and a **status**; T4 being `Partial` flags residual
  risk to carry into the residual-risks section.
