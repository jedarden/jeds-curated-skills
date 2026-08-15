# Changelog

All notable changes to skills in this repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Version field to all skill frontmatter (1.0.0 initial version for all 16 skills)

## [1.0.0] - 2026-05-16 to 2026-07-25

### Added
- **plan-review** - 2026-05-16
  - Initial release of comprehensive pre-flight review skill for software plans
  - Checks 80+ structural patterns across scope, acceptance criteria, architecture, safety, phasing, testing, security, performance, operations, API design, and risk

- **adr** - 2026-06-26
  - Architecture Decision Record authoring and review skill
  - Supports steel-manned alternatives and honest consequence documentation

- **api-design-review** - 2026-06-26
  - REST, gRPC, GraphQL, and CLI API surface review for design quality and evolvability
  - Checks resource modeling, semantics, versioning, payloads, and security

- **diff-review** - 2026-06-26
  - Language-agnostic structural code diff review with adversarial verification
  - Suppresses false positives through refutation pass

- **migration-runbook** - 2026-06-26
  - Reversible cutover/migration runbook authoring
  - Every step paired with verification gate and rollback

- **plan-author** - 2026-06-26
  - Inverse of plan-review: generates complete plan.md from brief
  - Produces all eleven structural categories plan-review checks for

- **postmortem** - 2026-06-26
  - Blameless incident postmortem authoring and review
  - Timeline, root-cause analysis, and owned action items

- **readme-review** - 2026-06-26
  - README quality review tuned to project type (library/CLI/service/app)
  - Zero-to-running walkthrough verification

- **release-readiness** - 2026-06-26
  - Go/no-go gate for releases with evidence-backed verdict
  - Checks quality, versioning, operations, and communications

- **spec-review** - 2026-06-26
  - Pre-plan gate for product/requirements specs
  - Reviews for ambiguity, untestable requirements, and missing NFRs

- **test-plan-review** - 2026-06-26
  - Suite-level test directory or test plan review
  - Identifies coverage gaps and tests that will lie

- **threat-model** - 2026-06-26
  - STRIDE-based threat model authoring and review
  - Enumerates assets, trust boundaries, data flows, and entry points

- **usage-statusline** - 2026-07-19
  - Live Claude Code statusline showing session and weekly usage
  - Rolling commit counter and time-to-exhaustion projection

- **gap-review** - 2026-07-21
  - Iterative gap-and-contradiction review for plans, specs, and design documents
  - Brainstorms 20 solutions per gap, applies best, re-analyzes until clean

- **plan-idea-gen** - 2026-07-21
  - Wide-then-narrow ideation anchored to plan.md
  - Generates pool of ideas via forced-diversity lenses, filters to top K through clustering and adversarial kill pass

- **repo-hygiene** - 2026-07-11
  - Repository hygiene audit with optional fix mode
  - Detects committed build artifacts, dead GitHub Actions, README drift, dirty trees, and suspicious tracked files
- **repo-hygiene** - 2026-07-25
  - Added root-ad-hoc-files check (bf-3o9 hygiene guard)

[Unreleased]: https://github.com/jedarden/jeds-curated-skills/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jedarden/jeds-curated-skills/releases/tag/v1.0.0
