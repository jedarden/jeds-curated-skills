# Section Header Taxonomy

Complete catalog of section headings found across 88 high-quality planning documents.
Use when evaluating whether a plan's structure is complete for its type.

---

## Document Framing Headers

```
## 0. How to Read This Document
## 0. What this plan is (and isn't)
### 0.1 Non-Negotiable Scope Doctrine
### 0.2 Normative Language (MUST/SHOULD/MAY defined)
### 0.3 Glossary
### 0.4 What "<Feature>" Means (No Weasel Words)
## Table of Contents
## CAVEAT: Ambition-First Operating Rule
## 0. Execution TODO (Canonical)         ← living checklist at doc top
## 0. Parity Matrix (As Of <date>)       ← living subsystem status table
## Background / Context
## Revision History
## Reading Guide
## Executive Summary / Thesis
## Problem Statement
## The Solution
## North Star Vision
```

## Scope Lock Headers

```
## What We Are Building
## What It Is NOT
## Non-Goals (Explicit Scope Boundaries)   ← each item has named rationale
## Explicit Exclusions
## Non-Negotiable Constraints
### Non-Negotiables (Engineering Contract)
### 0.5 Kernel Invariants (Must Always Hold)
## Hard Requirements
```

## Vision / Mission Headers

```
## North Star
### The one-sentence mission
## Core Thesis
## Strategic Objective
## Category-Creation Doctrine
## Impossible-by-Default Capability Index
### Success Metrics
## Design Principles
## Key Terminology / Glossary
```

## Architecture Headers

```
## Architecture Overview
## Architecture Blueprint
### System Overview
## Layered Mental Model
## Component Model
## Data Flow
## Threading / Concurrency Model
## File Layout / Project Structure
## Crate Dependency Graph
### Workspace Crate Map
## Trait Hierarchy
## Shared Patterns
### The Critical Separation: <A> vs <B>
## Method Stack (Required)
### Sibling-Repo Leverage Policy
### Determinism Boundary Contract
## Technology Stack
## Technology Decisions (Why X Over Y)
## API Surface
## Command Registry Pattern
## Agent Driver Abstraction
```

## Data & Storage Headers

```
## Core Data Models
## SQLite / DuckDB Tables & Schema
## Storage Architecture
## Source of Truth
## Concurrency Posture
## Database Locations
## JSONL Export
## Retention Policy
## State Directories
## Time Machine / Snapshots
## Memory Lifecycle (write/promotion/consolidation/decay)
```

## ADR / Decision Headers

```
## Design Decisions to Lock Early (Decision Records / ADRs)
## ADR Expansions (Lock Churn-Magnets Early)
## ADR-001 through ADR-00N
## Open Questions (Resolve Early; Track as ADRs)
```

## Phase / Implementation Headers

```
### Phase 0–N                    ← each layered on subsystem dependencies
### Phase A–E                    ← lettered for parallel work
### Track A–E                    ← parallel execution tracks
### Round R7–R41                 ← reverse rounds (most dependent to most primitive)
### Cross-Phase Acceleration Program
## Walking Skeleton
## Phased Execution Plan
## Migration (legacy mapping, keep/drop/reinterpret matrix)
## Installation & Deployment
```

## Pre-Flight / Safety Headers

```
## North Star Acceptance Scenarios
## Hard Requirements
## Non-Goals for V1
## Pre-flight Dry Run
## Pre-flight Syntax Validation
## Rollback Capture
## Risk Register & Mitigations
## Safety Boundaries / Invariants
## Failure Modes & Resilience
## Failure Taxonomy
## Failure Recovery Trees
## Edge Cases Catalog (numbered)
## Error Model & Taxonomy
## Fallback / Graceful Degradation
## Offline / Degraded Mode
## Anti-Patterns Catalog
## Trauma Guard / Confidence Decay
## Proof Obligations Ledger
## Regret Ledger
## Pitfalls to Avoid
## Final Safety Statement
```

## Testing Headers

```
## Testing Strategy
### Unit Tests (Per-Crate)
### Integration Tests
### Property-Based Tests (proptest)
### Fuzz Tests (cargo-fuzz)
### Conformance Harness
### File Format Round-Trip
### Concurrency Stress Tests
### Crash Recovery Verification
### Cumulative Test Count Targets
## Quality Gates (Stop-Ship if Failing)
## Definition of Done (v1)
### Verification Gate (All Phases)
### ADR-N: Tests (stop-ship)
## Pytest Coverage Checklist
## Acceptance Scenarios (pass/fail)
## SLOs / Performance Budget
## Monitoring & Alerting
## Release & Regression Process
## Incident Response Ladder
## Production Smoke Set
## Nightly Smoke Run
## Agent Readiness Checklist
```

## Security Headers

```
## Security Doctrine
## Threat Model
## Secrets Handling
## Remote Execution Safety
## Audit Logs
## Privacy & Redaction / Secret Sanitization
## Data Governance
### Bayesian Runtime Sentinel
### Supply-Chain Resilience Pipeline
### Deterministic Information Flow Control (IFC)
### Untrusted Output Policy (Sanitize-by-Default)
## Security Threat Matrix              ← table: threat → vector → mitigation → test
```

## Performance Headers

```
## Performance Budgets (v1)            ← p50/p99 tables, bytes/frame, allocs/frame
### Benchmark Denominator Contract For >= 3x Claim (Binding)
### Measurement Artifacts (Required Per Change)
## Scalability Limits
## CI-Gated Benchmarks
```

## UX / Interface Headers

```
## CLI (human mode + robot/JSON mode as dual surfaces)
## TUI Layout
## Web Dashboard
## Agent JSON Contract / Robot Mode Spec
## Streaming / Watch Mode / Event Stream
## Natural Language Interface
## MCP Server Mode
## Keyboard-First Design / Hotkey Map
## Token Budget (AI-native tools)
```

## Operations / Deployment Headers

```
## Deployment Plan
## Migration Plan
## Keep / Drop / Reinterpret Matrix
## Backward Compatibility Stance
## Rollout / Rollback Criteria
## Go / No-Go Checkpoint
## Non-Interactive / CI Mode
## Monitoring & Alerting
## Doctor Command / Health Check
## Data Format Compatibility
```

## Integration Headers

```
## Dependency Integration Contracts (per-dep)
## Agent Mail Integration
## Flywheel / Ecosystem Context
## Sibling-Repo / Dependency Leverage Policy
### End-to-End Test Ownership
### Rollback Coordination
```

## Port-Specific Headers

```
## Parity Matrix (As Of <date>)        ← living: location | status | gaps
## Migration Map and Integration Strategy
## Terminal Compatibility Matrix
## Parity Gaps vs. Original
## Total LOC Estimate                  ← per-phase table, legacy vs target LOC ratio
### Source Metrics                     ← analyze source before estimating output
## Porting Order Defined
## Conformance Harness
## File Format Round-Trip Tests
## ABI / FFI Stance
```

## Improvement-Plan-Specific Headers

```
## Gap Inventory
## What We're NOT Changing
## Incident Class Prevention
## Existing Data Format Compatibility
## Rollback Criteria Before Rollout
## Behavioral Regression Tests
```
