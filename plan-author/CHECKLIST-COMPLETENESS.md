# Completeness Checklist

The bar a generated plan must clear. Mirrors the eleven `plan-review` categories, but read as
GENERATIVE TARGETS: every box should be checkable by the time the plan is written. Each item
carries a one-line "good looks like" note. The self-score script in
`~/.claude/skills/plan-author/scripts/score-draft.sh` greps for these; the drafter and the
backfill step satisfy them.

A section that is a single vague sentence does NOT pass. A section that hides everything behind
bare "TBD" does NOT pass — genuine unknowns belong in §16 Open Questions, numbered, with owners.

## 1. Scope Lock
- [ ] **1.1 North Star** — one sentence stating success, written before architecture.
- [ ] **1.2 Non-Goals with rationale** — each exclusion names *why*, not just *what*.
- [ ] **1.3 Hard Requirements** — MUST/MUST NOT list incl. forbidden deps and patterns.
- [ ] **1.4 Glossary** — every ambiguous term defined once, normatively.
- [ ] **1.5 Normative language** — MUST/SHOULD/MAY declared and used consistently.

## 2. Acceptance
- [ ] **2.1 Acceptance scenarios** — numbered, setup/action/expected, concrete.
- [ ] **2.2 Pass AND fail criteria** — both stated per scenario, testable.
- [ ] **2.3 Error/degraded + recovery scenario** — at least one of each beyond the happy path.

## 3. Architecture
- [ ] **3.1 Component overview** — named components with single responsibilities.
- [ ] **3.2 Data flow** — one operation traced end-to-end.
- [ ] **3.3 Concurrency/execution model** — threading/async/ownership stated explicitly.
- [ ] **3.4 Technology decisions** — each major choice justified over its alternative.

## 4. Data Model
- [ ] **4.1 Core entities** — fields and types for the durable shapes.
- [ ] **4.2 Source of truth & storage** — authoritative store, location, retention named.

## 5. Pre-Flight Safety
- [ ] **5.1 Edge case catalog** — numbered (EC-NN) cases, each with a resolution.
- [ ] **5.2 Failure modes & recovery** — mode → detection → recovery → data-safety mapping.
- [ ] **5.3 Invariants** — conditions that must always hold.
- [ ] **5.4 Rollback** — how a bad change is undone and what state is captured.

## 6. Phasing
- [ ] **6.1 Walking skeleton** — Phase 0: one command through every layer, throwaway quality.
- [ ] **6.2 Phases named** — ordered, each delivering a slice.
- [ ] **6.3 Completion criteria** — per phase, all passing on the same commit, with a "does NOT include".

## 7. Testing
- [ ] **7.1 Test levels** — unit/integration/scenario mapped to what each protects.
- [ ] **7.2 Quality gates** — stop-ship conditions that block release.

## 8. Security
- [ ] **8.1 Threat model** — attacker, surface, per-threat mitigation + test (or explicit "trivial because…").
- [ ] **8.2 Secrets handling** — source, storage, never-logged rule.

## 9. Performance
- [ ] **9.1 Performance budget** — numeric targets on named conditions (or explicit non-budget + why).
- [ ] **9.2 Measurement method** — how each number is verified.

## 10. Operations
- [ ] **10.1 Deployment & config** — install/deploy path + non-interactive/CI invocation.
- [ ] **10.2 Migration / backward-compat** — keep/drop/reinterpret for existing systems (N/A for greenfield).
- [ ] **10.3 Monitoring / health** — health signals + a doctor/health-check entry point.

## 11. API / Interface
- [ ] **11.1 Interface surface** — commands/endpoints/signatures with inputs and outputs.
- [ ] **11.2 Error contract** — how failures are surfaced to the consumer (human and machine).

## 12. Risk
- [ ] **12.1 Risk register** — ranked risks with likelihood/impact/mitigation.
- [ ] **12.2 Plan B** — named fallback for the riskiest assumption.

## 13. Hygiene
- [ ] **13.1 Open Questions** — genuine unknowns numbered, with owner + resolve-by phase.
- [ ] **13.2 Revision history / date stamp** — plan is dated and traceable.
