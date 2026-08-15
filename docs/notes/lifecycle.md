# SDLC Lifecycle Map

This document maps the agent-driven software development lifecycle to the specific skills to invoke at each stage.

## Overview Flow

```
[spec-exists?] ──yes──> spec-review ──┐
                                      │
                                      v
[brief-only?] ────────────────> plan-author ──> plan-review ──> [implement]
                                                                           │
                                                                           v
                                                ┌──────────────────────────────────────┐
                                                │                                      diff-review
                                                │                                              │
                                                v                                              v
                                        test-plan-review                                  api-design-review
                                                │                                              │
                                                v                                              v
                                              threat-model ────────────────────────────────────┘
                                                      │
                                                      v
                                              release-readiness
                                                      │
                                                      v
                                              postmortem (if incident occurs)
```

## Branch Points

### 1. Spec vs. Brief Entry Point

**When you have a full PRD or requirements document:**
```
spec.md → /spec-review → plan-author → plan-review → [implementation]
```

**When you have only a short brief or idea:**
```
brief → /plan-author → plan-review → [implementation]
```

### 2. Plan Type Handling

The `plan-author` and `plan-review` skills handle all four plan types:

- **Greenfield:** New project from scratch
- **Port:** Rewrite/translation of existing codebase to new stack
- **Improvement:** Feature addition or refactor of existing system
- **Integration:** System integration or connector work

The skills auto-detect plan type from context or prompt.

## Stage → Skill Mapping

### Pre-Implementation Phase

| Stage | Skill | When to Invoke |
|-------|-------|----------------|
| **Spec Review** | `spec-review` | You have a PRD or requirements doc; run before writing plan |
| **Plan Authoring** | `plan-author` | Converting brief/idea to full plan.md |
| **Plan Review** | `plan-review` | Pre-flight check of plan.md before implementation starts |
| **Gap Analysis** | `gap-review` | Iterative gap/contradiction review of plan, spec, or design doc |
| **Idea Generation** | `plan-idea-gen` | Need large pool of ideas anchored to a specific plan.md |

### Implementation Phase

| Stage | Skill | When to Invoke |
|-------|-------|----------------|
| **Code Review** | `diff-review` | Reviewing a code diff before commit ( correctness bugs, design/cleanup issues) |
| **Test Plan Review** | `test-plan-review` | Review test coverage gaps; run before or during implementation |
| **API Design Review** | `api-design-review` | Reviewing REST, gRPC, GraphQL, or CLI API before it's locked |

### Pre-Release Phase

| Stage | Skill | When to Invoke |
|-------|-------|----------------|
| **Threat Modeling** | `threat-model` | Produce or review STRIDE-based threat model before release |
| **Security Review** | `security-review` | General security audit (if needed) |

### Release & Operations Phase

| Stage | Skill | When to Invoke |
|-------|-------|----------------|
| **Release Readiness** | `release-readiness` | Go/no-go gate before cutting release, tag, or deploy |
| **Migration Planning** | `migration-runbook` | Authoring reversible cutover or migration runbook |
| **Post-Incident** | `postmortem` | Author blameless postmortem after incident occurs |

### Cross-Cutting Skills (Any Stage)

| Skill | When to Invoke |
|-------|----------------|
| **ADR** | When architectural decisions need to be recorded or reviewed |
| **README Review** | When README changes; ensure docs match project state |
| **Repo Hygiene** | Audit repository for hygiene debt (committed artifacts, large files, dead workflows) |
| **Usage Statusline** | Install once for live Claude Code usage tracking |

## Typical Workflows

### Greenfield Project (With Spec)

```bash
# 1. Review the spec
/spec-review docs/specs/feature.md

# 2. Author the plan (reads brief and auto-scans for context)
/plan-author --out docs/plan/plan.md

# 3. Review the plan before implementation
/plan-review docs/plan/plan.md

# 4. Implement (your workflow here)

# 5. Review the implementation diff
/diff-review main

# 6. Review test coverage
/test-plan-review tests/

# 7. If API surface defined, review API design
/api-design-review api/openapi.yaml

# 8. Threat model before release
/threat-model author docs/architecture.md

# 9. Release readiness check
/release-readiness
```

### Greenfield Project (Brief Only)

```bash
# 1. Author plan directly from brief
/plan-author "Add user authentication" --out docs/plan/plan.md

# 2. Review the plan
/plan-review docs/plan/plan.md

# Continue from step 4 above...
```

### Port/Improvement Project

```bash
# 1. Author plan (auto-scans existing codebase for context)
/plan-author --out docs/plan/plan.md

# 2. Review the plan (auto-detects port/improvement type)
/plan-review docs/plan/plan.md

# Continue from step 4 above...
```

### Post-Incident Workflow

```bash
# 1. Author postmortem
/postmortem "API outage 2024-08-15"

# 2. Create ADRs for any architectural decisions
/adr author "Add circuit breaker to prevent cascading failures"

# 3. Update plans and implement fixes
# (return to main workflow)
```

## Continuous Practices

These skills can be invoked at any time, independent of the main lifecycle flow:

- **Gap Review:** Run `/gap-review` on any plan, spec, or design document when you need fresh-eyes contradiction/ambiguity analysis
- **Idea Generation:** Run `/plan-idea-gen` when you need a large pool of candidate ideas for a specific plan
- **Migration Planning:** Run `/migration-runbook` whenever you need a reversible migration plan
- **Repo Hygiene:** Run `/repo-hygiene` periodically to detect and fix technical debt
- **README Review:** Run `/readme-review` after any user-facing changes

## Notes

- All skills are self-contained and spawn their own subagents
- Skills work headlessly — no human steering required mid-execution
- Skills auto-detect project type, plan type, and context from repo state
- Run skills in sequence as shown; each produces artifacts the next can consume
