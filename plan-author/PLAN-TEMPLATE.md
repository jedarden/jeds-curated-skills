# Plan Template

The section skeleton a generated plan fills in. Order is canonical. Each section carries a
`<!-- guidance -->` comment describing what "good" looks like; the drafter replaces the
placeholder prose with plan-specific content and deletes the guidance comments in the final file.

Heading levels: `#` for the title, `##` for categories, `###` for sub-sections. Keep them stable
so `plan-review` and the scoring script can find every section.

---

# <Project Name>

> One-line tagline. What this is, in plain words.

**Type:** Greenfield | Port | Improvement | Integration
**Status:** Draft
**Last updated:** <YYYY-MM-DD>

---

## 1. Mission & North Star

<!-- guidance: ONE sentence stating what success looks like, written before any architecture.
     Then 2-4 lines of self-contained background so a fresh reader needs no external context. -->

**North Star:** <single sentence — "Success is when a user can <do X> and observe <Y>.">

**Background:** <why this exists, what problem it solves, what came before.>

## 2. Non-Goals (Explicit Scope Boundaries)

<!-- guidance: each non-goal has a NAMED rationale — "excluded X because Y", not just "no X".
     Weak: "No multi-tenancy." Strong: "No multi-tenancy — single-team tool; tenancy would
     force an auth model and triple the data layer for zero current users." 3-6 items. -->

- **<Excluded thing>.** <Why it is out of scope, and what the right tool/time would be.>
- **<Excluded thing>.** <Rationale.>

## 3. Hard Requirements (Non-Negotiable)

<!-- guidance: things that MUST or MUST NOT hold and cannot be traded away. Include forbidden
     dependencies and forbidden patterns. Use normative MUST/MUST NOT. -->

- The system **MUST** <…>.
- The system **MUST NOT** <…>.
- **Forbidden dependencies/patterns:** <…>.

### 3.1 Normative Language

The key words MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY follow RFC 2119. When capitalized
they are binding; in lowercase prose they are descriptive.

## 4. Glossary

<!-- guidance: define every term two readers could interpret differently. Prevents "we had
     different mental models" mid-build. Even 3-4 entries beat zero. -->

- **<Term>** — <precise definition as used in this document.>
- **<Term>** — <definition.>

## 5. Acceptance Scenarios

<!-- guidance: concrete, numbered, setup/action/expected with explicit pass AND fail criteria.
     Include at least one happy path, one error/degraded path, and one recovery path. These are
     the contract; architecture exists to satisfy them. -->

### Scenario 1: <Happy Path Name>
- **Setup:** <starting state.>
- **Action:** <what the user/agent does.>
- **Expected:** <observable result, exact where possible.>
- **Pass:** <bulleted, testable conditions.>
- **Fail:** <conditions that mean this scenario failed.>

### Scenario 2: <Error / Degraded Path>
- **Setup / Action / Expected / Pass / Fail:** <as above — e.g. dependency unavailable.>

### Scenario 3: <Recovery Path>
- **Setup / Action / Expected / Pass / Fail:** <e.g. interrupted mid-operation, then restarted.>

## 6. Architecture

<!-- guidance: components, how data flows, and WHY each major technology was chosen over the
     obvious alternative. A diagram-in-prose is fine. Name real components — they get referenced
     everywhere downstream. -->

### 6.1 Component Overview
<Layered view: each component, its single responsibility, and what it talks to.>

### 6.2 Data Flow
<Trace one representative request/operation end-to-end through the components.>

### 6.3 Concurrency / Execution Model
<Threading, async, single-writer, ownership, scheduling. State the model explicitly.>

### 6.4 Technology Decisions (Why X Over Y)
<Each significant choice: what was chosen, the alternative, and the deciding reason.>

## 7. Data Model

<!-- guidance: the durable shapes — tables/structs/messages with fields and types. Name the
     source of truth, the storage location, and the retention/migration posture. -->

### 7.1 Core Entities
<Each entity: fields, types, key constraints. A table or fenced schema block is ideal.>

### 7.2 Source of Truth & Storage
<Where state lives, what the authoritative store is, how it is exported/backed up.>

## 8. Pre-Flight Safety

<!-- guidance: THE core "no in-flight pivot" section. Numbered edge cases each with a resolution,
     a failure-mode -> recovery mapping, invariants that must always hold, and a rollback path.
     This is where thin plans pivot. Be exhaustive here. -->

### 8.1 Edge Case Catalog
- **EC-01: <case>** — Resolution: <exact behavior, including exit codes / messages.>
- **EC-02: <case>** — Resolution: <…>
- **EC-03: <case>** — Resolution: <…>

### 8.2 Failure Modes & Recovery
| Failure | Detection | Recovery | Data Safety |
|---------|-----------|----------|-------------|
| <mode>  | <signal>  | <action> | <guarantee> |

### 8.3 Invariants (Must Always Hold)
- <Invariant that, if violated, indicates a bug regardless of inputs.>

### 8.4 Rollback
<How a bad release/change is undone, and what state is captured to make undo possible.>

## 9. Phasing

<!-- guidance: ordered phases, each with completion criteria that all pass on the SAME commit,
     and an explicit "does NOT include". Phase 0 is a walking skeleton: one command end-to-end
     through every layer, throwaway quality, proving the wiring. -->

### Phase 0: Walking Skeleton
**Goal:** prove the wiring — one operation traverses every layer and returns a real result.
**Delivers:** <minimal end-to-end path.>
**Does NOT include:** error handling, performance, broad tests.
**Exit criteria:** <one concrete command + expected output.>

### Phase 1: <Name>
**Delivers:** <…>
**Completion criteria (all on the same commit):** <tests, lint, a manual check.>
**Does NOT include:** <deferred items + which phase owns them.>

### Phase N: <Name>
<As above.>

## 10. Testing Strategy & Quality Gates

<!-- guidance: levels of testing mapped to what each protects, plus stop-ship gates. Tie back
     to the acceptance scenarios in §5. -->

### 10.1 Test Levels
- **Unit:** <what.>  **Integration:** <what.>  **End-to-end / scenario:** <maps to §5.>
- <Property/fuzz/conformance/crash-recovery as the type warrants.>

### 10.2 Quality Gates (Stop-Ship)
- <Gate — e.g. all acceptance scenarios pass, lint clean, coverage threshold — that blocks release.>

## 11. Security & Threat Model

<!-- guidance: who the attacker is, the attack surface, and per-threat mitigation + how it is
     tested. Secrets handling: where they come from, that they are never logged. If genuinely
     trivial (e.g. offline single-user CLI), say so explicitly with reasoning — do not omit. -->

| Threat | Vector | Mitigation | Test |
|--------|--------|------------|------|
| <…>    | <…>    | <…>        | <…>  |

**Secrets:** <source, storage, and the rule that they are never logged or echoed.>

## 12. Performance Budgets

<!-- guidance: numeric targets (p50/p99 latency, throughput, memory, allocs) on named reference
     hardware, and how they are measured. "Fast" is not a budget. If perf is not a concern, state
     the explicit non-budget and why. -->

| Metric | Budget | Reference Condition | How Measured |
|--------|--------|---------------------|--------------|
| <…>    | <…>    | <…>                 | <…>          |

## 13. Operations (Deploy, Migration, Monitoring)

<!-- guidance: how it ships, how it is configured, how it runs non-interactively (CI), how it is
     observed, and — for improvement/port — the migration of existing data/users with a
     keep/drop/reinterpret stance. -->

### 13.1 Deployment & Configuration
<How it is installed/deployed, what config it needs, the non-interactive/CI invocation.>

### 13.2 Migration (if evolving an existing system)
<Keep / drop / reinterpret matrix for existing data and behavior. Backward-compat stance.>

### 13.3 Monitoring & Health
<What signals indicate health, and the doctor/health-check entry point.>

## 14. API / Interface Design

<!-- guidance: the surface consumers touch — CLI flags, HTTP routes, function signatures, message
     formats. For agent-facing tools, specify the machine (JSON) surface alongside the human one. -->

<Commands / endpoints / signatures, inputs and outputs, and error contract. Dual human + machine
surfaces where relevant.>

## 15. Risk Register & Plan B

<!-- guidance: ranked risks with likelihood/impact/mitigation, and at least one named Plan B for
     the riskiest assumption — the fallback if the primary approach fails. -->

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | <…> | <…>       | <…>    | <…>        |

**Plan B:** <if <riskiest assumption> proves false, the fallback is <alternative approach>.>

## 16. Open Questions

<!-- guidance: genuine unknowns ONLY — numbered, each with an owner and a resolve-by phase. This
     is where the drafter parks what it could not legitimately decide. NEVER use bare "TBD"
     scattered through the body; centralize the unknowns here. -->

1. **<Question>** — Owner: <role>. Resolve by: Phase <n>. Impact if wrong: <…>.
2. **<Question>** — Owner / Resolve by / Impact.

## 17. Revision History

| Date | Change | Author |
|------|--------|--------|
| <YYYY-MM-DD> | Initial draft generated from brief. | plan-author |
