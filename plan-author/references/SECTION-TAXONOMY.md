# Section Taxonomy

The canonical section headers for a generated plan, in order, with one line each on purpose.
The drafter follows this ordering exactly so that downstream `plan-review` and the scoring script
find every section by its heading. This is the generative mirror of plan-review's larger header
catalog — trimmed to the headers a fresh plan should actually contain.

| # | Header | Purpose |
|---|--------|---------|
| — | `# <Project Name>` | Title + one-line tagline + type/status/date metadata. |
| 1 | `## 1. Mission & North Star` | The single success sentence and self-contained background. |
| 2 | `## 2. Non-Goals (Explicit Scope Boundaries)` | What is out of scope, each with a named rationale. |
| 3 | `## 3. Hard Requirements (Non-Negotiable)` | MUST / MUST NOT, forbidden deps and patterns. |
| 3.1 | `### 3.1 Normative Language` | RFC-2119 declaration so MUST/SHOULD/MAY are binding. |
| 4 | `## 4. Glossary` | Definitions for every term two readers could read differently. |
| 5 | `## 5. Acceptance Scenarios` | Numbered setup/action/expected with pass AND fail criteria. |
| 6 | `## 6. Architecture` | Components, data flow, concurrency, and tech-choice rationale. |
| 6.1 | `### 6.1 Component Overview` | Each component, its responsibility, its neighbors. |
| 6.2 | `### 6.2 Data Flow` | One operation traced end-to-end. |
| 6.3 | `### 6.3 Concurrency / Execution Model` | Threading/async/ownership stated explicitly. |
| 6.4 | `### 6.4 Technology Decisions (Why X Over Y)` | Each major choice justified over its alternative. |
| 7 | `## 7. Data Model` | The durable shapes and where the truth lives. |
| 7.1 | `### 7.1 Core Entities` | Fields and types for each entity. |
| 7.2 | `### 7.2 Source of Truth & Storage` | Authoritative store, location, retention. |
| 8 | `## 8. Pre-Flight Safety` | The core "no in-flight pivot" section. |
| 8.1 | `### 8.1 Edge Case Catalog` | Numbered EC-NN cases, each with a resolution. |
| 8.2 | `### 8.2 Failure Modes & Recovery` | Mode → detection → recovery → data-safety. |
| 8.3 | `### 8.3 Invariants (Must Always Hold)` | Conditions that signal a bug if violated. |
| 8.4 | `### 8.4 Rollback` | How a bad change is undone; what state is captured. |
| 9 | `## 9. Phasing` | Ordered phases with same-commit completion criteria. |
| 9.0 | `### Phase 0: Walking Skeleton` | One command through every layer, throwaway quality. |
| 10 | `## 10. Testing Strategy & Quality Gates` | Test levels mapped to risk + stop-ship gates. |
| 11 | `## 11. Security & Threat Model` | Attacker, surface, per-threat mitigation + test; secrets. |
| 12 | `## 12. Performance Budgets` | Numeric targets on named conditions + measurement method. |
| 13 | `## 13. Operations (Deploy, Migration, Monitoring)` | Ship, configure, migrate, observe. |
| 14 | `## 14. API / Interface Design` | The surface consumers touch; human + machine. |
| 15 | `## 15. Risk Register & Plan B` | Ranked risks + a named fallback for the riskiest. |
| 16 | `## 16. Open Questions` | Genuine unknowns, numbered, with owner + resolve-by phase. |
| 17 | `## 17. Revision History` | Dated change log; proves the plan is not stale. |

## Type-Specific Additions

Insert these where the table note points; keep the base numbering otherwise.

- **Port** — under §6: `## Parity Matrix (As Of <date>)` (location | status | gaps),
  `## Source Metrics` (analyze source LOC before estimating), `## Porting Order`,
  and under §10: `### Conformance Harness`, `### File Format Round-Trip`.
- **Improvement** — under §2: `## What We're NOT Changing`; under §5: `## Gap Inventory`;
  under §10: `### Behavioral Regression Tests`; under §13: `### Rollback Criteria Before Rollout`.
- **Integration** — under §6: `## Dependency Integration Contracts (per-dep)`; under §8:
  `### Failure Isolation Between Systems`; under §13: `### Rollback Coordination`.
