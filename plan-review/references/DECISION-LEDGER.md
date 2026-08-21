# Decision Ledger — the fork catalog

A **fork** is any point where an implementer must pick one of several viable options and the
pick is expensive to reverse. Plans pivot when an implementer reaches a fork the plan never
chose. This catalog is the *generator* for Lens A: walk it domain by domain against the plan
and ask, for each fork, "does this system have it, and what state is it in?"

Every entry: the fork · what "left open" costs (the incident it becomes) · what LOCKED looks
like. The costs are drawn from the pivot patterns observed across ~340 planning documents and
from this workspace's own post-hoc ADRs — each of which is a fork that reached production
unchosen.

States (from SKILL.md): LOCKED · ASSERTED · RECOMMENDED · SPIKED · DEFERRED · UNNOTICED · SHADOW.
Stakes: **H** high reversal cost · **M** medium · **L** low. Stakes are a default; a plan's
own context can move them.

---

## 1. Identity & shape

| # | Fork | Stakes | Left open → | LOCKED looks like |
|---|---|---|---|---|
| 1.1 | **Language / runtime / toolchain pin** | H | Phase 1 blocked for days; "ratify Go" ADR appended after the plan passed review; a worker re-scopes its bead instead of building | Named language, pinned toolchain file, the *one* library that decided it, the runner-up kept as fallback |
| 1.2 | **Deployment unit** (binary / container / library / service / edge function) and **where it runs** (cluster, namespace, node class) | H | Manifests written for the wrong cluster; storage class unavailable; CI template doesn't exist | Unit + host + namespace named; the house rule that constrains it cited |
| 1.3 | **Repo topology** (new vs. existing repo; visibility; mirror) | M | A private plan mirrored publicly; a public tool hidden | Repo path, visibility, and mirror stance stated with the reason |
| 1.4 | **Build & CI path** (which template/pipeline; image name; tag policy) | M | "CI wiring TBD" for months; `:latest` rejected at sync time | Template named or its creation is Phase N's first task; tag source (`VERSION`) named |
| 1.5 | **Versioning & release** (semver? what bumps? changelog?) | M | Consumers can't tell breaking from additive; no rollback target | Scheme + what constitutes a breaking change + how a release is cut |
| 1.6 | **Scope doctrine** (phases are sequencing, not optionality) | M | "Phase 6 is optional, right?" — silently dropped features | One sentence: everything described is in scope; exclusions live in Non-Goals with rationale |

## 2. Data

| # | Fork | Stakes | Left open → | LOCKED looks like |
|---|---|---|---|---|
| 2.1 | **Source of truth** when two stores exist (db vs. log; cache vs. origin; local vs. remote) | H | Two writers, divergent state, "which one is right?" | One store authoritative; the other rebuildable from it; the rebuild path is a named command |
| 2.2 | **Storage engine** + class/volume | H | Rewrite of the persistence layer; volume that can't be resized | Engine + the property that chose it (single-writer, ACID, indexed…) + storage class named explicitly |
| 2.3 | **Schema evolution** (migrations? additive-only? versioned?) | H | Populated-table migration at 2 a.m.; incompatible JSONL across versions | Policy stated: how fields are added, how readers treat unknown fields, where the version lives |
| 2.4 | **ID scheme** (UUID / ULID / sequence / content hash) + collision policy | H | Merge conflicts across replicas; unstable IDs break external references | Scheme + who mints + uniqueness scope + what a collision does |
| 2.5 | **Serialization / wire format** + version marker | H | `--json` bolted on later diverges from human output | One machine format primary, versioned; human rendering is a view over it |
| 2.6 | **Retention & growth bound** (TTL, size cap, eviction, archive) | M | Disk-full at cache-miss time → 500s; no alarm before it | Bound + enforcement loop + observable size signal |
| 2.7 | **Cache invalidation / staleness** — which responses are immutable, which are time-varying | M | A "give me the latest" query cached forever; client reports "0 new" for 9 days; two ADRs and an incident | Classification rule by request shape + TTL per class + bypass header |
| 2.8 | **Time & clock** (UTC; monotonic vs. wall; event vs. ingest time; timezone of display) | M | Off-by-DST bugs; ordering flips after a restart | Stated per field; monotonic for durations, UTC for storage, local only at render |
| 2.9 | **Backup & restore** (artifact, cadence, tested restore, off-box copy) | H | Backups that were never restored; faulted volume takes the only copy | Artifact + cadence + destination + a restore drill in a phase's completion criteria |
| 2.10 | **Idempotency & dedup keys** for writes/ingest | M | Double-billing, duplicate rows on retry | Key definition + where enforced (unique index, upsert) |

## 3. Control flow

| # | Fork | Stakes | Left open → | LOCKED looks like |
|---|---|---|---|---|
| 3.1 | **Concurrency model** (single-writer? replicas=1 as invariant? async runtime? locks?) | H | Data races; a second replica silently breaks per-process guards | Model stated; `replicas: 1` (or the lock) named as an invariant with a test |
| 3.2 | **Retry policy** (what is retryable; backoff; max attempts; poison handling) | M | Retry storms; a poison message blocks the queue forever | Table: error class → retry? → backoff → give-up action |
| 3.3 | **Ordering & delivery** (at-least / at-most / exactly once; reorder tolerance) | H | Duplicate side effects; lost events nobody noticed | Guarantee named + the dedup mechanism that makes it true |
| 3.4 | **Failure policy per dependency** (fail-open vs. fail-closed; degraded mode) | H | Secret store down ⇒ either outage or unauthenticated requests — decided at 3 a.m. | Per dependency: unavailable ⇒ behaviour, user-visible message, recovery |
| 3.5 | **Timeouts & budgets** (per call, per request, per job) | M | Hung workers; unbounded queues | Numbers, with the reason for each number |
| 3.6 | **Scheduling** (internal loop vs. external trigger; interval; jitter; overlap guard) | M | Two sweeps overlap; a Job is written where the house forbids Jobs | Mechanism + interval + what prevents overlap |
| 3.7 | **Cancellation & shutdown** (SIGTERM handling, drain, in-flight work) | M | Half-written files on every deploy | Signal → drain window → what is abandoned vs. finished |
| 3.8 | **Startup & readiness** (what must be true to serve; health/doctor) | M | Pod "ready" while its dependency is down | Readiness condition list + `/health` or `doctor` semantics |
| 3.9 | **Rebuild / recovery path** from the durable source | H | "Restore" documented nowhere; improvised during an incident | A command, its inputs, the expected end state, a test that runs it |

## 4. Interfaces

| # | Fork | Stakes | Left open → | LOCKED looks like |
|---|---|---|---|---|
| 4.1 | **Primary consumer** (human / script / agent / service) and the **machine surface** | H | Works for humans, not for scripts; ANSI in pipes | Consumer named; machine mode is first-class, TTY detection stated |
| 4.2 | **Surface shape** (commands/flags/routes; exit codes; status codes) | H | Breaking CLI change in v0.2 | Surface enumerated before code; exit/status code table |
| 4.3 | **Error model** (taxonomy, codes, retryable flag, machine-readable body) | M | Every module invents its own error shape | One taxonomy, one body shape, grouped codes with recovery advice |
| 4.4 | **Config surface** (env / file / flags; precedence; validation; secrets separated) | M | Twelve env vars with no precedence rule; a secret in a config file | Precedence order + validation at startup + secrets only by reference |
| 4.5 | **Compatibility stance** (what's stable; deprecation policy) | M | Implicit promises broken; consumers angry | Stated even when "none" |
| 4.6 | **Pagination / streaming / batching shape** | M | Cursor semantics change mid-series; clients break | Shape + cursor opacity + page-size bounds |
| 4.7 | **Logging** (format, levels, what is never logged) | L–M | Secrets in logs; unparseable logs | Structured format + explicit never-log list |
| 4.8 | **Token / output budget** (agent-consumed tools) | M | 40k-token responses to an agent | Compact mode + budget numbers |

## 5. Security & trust

| # | Fork | Stakes | Left open → | LOCKED looks like |
|---|---|---|---|---|
| 5.1 | **Auth model** (who may call; identity source) | H | Open endpoint on the tailnet "for now" | Identity source + enforcement point + test |
| 5.2 | **Authorization granularity** (per-route / per-method / per-caller scopes) | H | A fragment-root scope can't express "GET ok, DELETE not" — redesign | Granularity + combination rule (conjunction/union) + the 403 semantics |
| 5.3 | **Secrets path & injection** (store path; how mounted; rotation) | H | Value in a commit; rotation impossible | Store path by reference, injection mechanism, rotation procedure; value never appears |
| 5.4 | **Exposure** (public / VPN / cluster-local; which entrypoint) | H | Second Tailscale exposure where the house allows one; public by accident | Entrypoint named + the rule it satisfies + the test from outside the boundary |
| 5.5 | **Trust boundary & untrusted input policy** | H | Injection via the one unvalidated path | Blanket policy: what is untrusted, where it is validated, what is rejected |
| 5.6 | **Audit** (what is recorded, what is never) | M | Either no trail or secrets in the trail | Event list + never-record list |

## 6. Delivery

| # | Fork | Stakes | Left open → | LOCKED looks like |
|---|---|---|---|---|
| 6.1 | **First ship unit / walking skeleton** | H | Everything required before anything is demonstrable | One command through every layer, throwaway quality, exact expected output |
| 6.2 | **Phase order & gates** (entry/exit criteria; ship order vs. phase numbers) | M | "Are we on track?" unanswerable; Phase 2 on a broken Phase 1 | Per phase: delivers / completion criteria on one commit / does NOT include |
| 6.3 | **Rollout & rollback mechanism** | H | No way back after a bad deploy | Mechanism (e.g. manifest digest revert) + trigger + who decides |
| 6.4 | **Migration / cutover of existing data or users** | H | Existing users broken; no shadow period | Keep/drop/reinterpret matrix + shadow/canary + cut-over gate |
| 6.5 | **Observability** (metrics, dashboards, alerts, "healthy" definition) | M | Silent failure for a week | Signals + thresholds + where they are seen |
| 6.6 | **Test oracle** (conformance vs. original; golden files; property tests) | H for ports | Tests pass, port is wrong | Oracle named; byte-level comparison in CI from day one |
| 6.7 | **Performance budget & denominator** (numbers; reference hardware; methodology) | M | "3× faster" claims nobody can reproduce | Numbers + how measured + what blocks publication |
| 6.8 | **Human gates** — which decisions require a person, and when | H | A worker decides architecture; or waits forever | Named gates as explicit blocking work items with a resolve-by phase |
| 6.9 | **Bead / task decomposability** — can every phase become single-task units? | M | A vague bead claimed twice, implemented twice | Phases written as verb-phrase tasks; no task needs a design call |

## 7. House rules (read them, never hardcode them)

Every hard prohibition in the governing `CLAUDE.md` / `AGENTS.md` (found from the plan's
directory up to `$HOME`) is a fork the plan must already comply with. Typical shapes: banned
workload kinds, banned CI systems, mandated storage classes, exposure limits, secrets-by-
reference, image-tag pinning, change-through-GitOps-only, no-force-push. A plan that violates
one will be rejected at PR or sync time — that is a pivot with a 100% probability (Cap C6).

---

## Classifying quickly

| The plan says… | State |
|---|---|
| "SQLite (single-writer). A JSON file would rewrite the whole document per update and has no crash-safe partial write. We accept the single-writer limit because §6.3 fixes writers at one. Revisit if a second writer is ever required. Test: `cargo test store::concurrent_writer_rejected`." | LOCKED |
| "SQLite on a Longhorn PVC." | ASSERTED (fine unless the engine choice is contested) |
| "Backup interval — candidate default every 15 minutes; shorten if B2 egress cost is < $1/mo at that rate." | RECOMMENDED |
| "Whether WebGPU beats Canvas at 10k agents is measured in Week 1 on Chrome 139 + Safari 26; decision recorded by Week 2; default Canvas if inconclusive." | SPIKED |
| "registry (target TBD, see Open Questions)" · "Rust, likely axum" · "e.g. every 15 minutes" | DEFERRED |
| *(nothing — but the system caches responses and some are time-varying)* | UNNOTICED |
| An `## ADR-001` at line 1084 of 1109 ratifying the language; "decided 2026-07-20" inside a 900-word paragraph; a `~~struck~~` open question whose answer never reached the Architecture section | SHADOW |

## What "propose the decision" means

Not "add an ADR". Write the decision the plan should contain, in its own voice, in five lines:

> **Decision:** per-query-shape TTL — requests with an absent or empty `cursor` are "front
> page" and expire after 300 s; any non-empty cursor is immutable and cached forever.
> **Because:** the same cache holds time-varying and immutable answers, and a single global TTL
> cannot tell them apart; `cursor` is already parsed. **Rejected:** global `CACHE_TTL_SECS`
> (breaks the archival guarantee); fixing the one client (next client repeats it).
> **Enforced by:** `cache::front_page_expires` test; `X-Cache-Status: stale-refresh` header.
> **Revisit if:** a caller needs a different front-page TTL — make it per-route config then.

If you cannot write that paragraph from what the plan and the repo give you, the honest
proposal is a spike with a metric and a date, or a named human gate — still never `[FILL IN]`.
