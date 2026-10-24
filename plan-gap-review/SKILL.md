---
name: plan-gap-review
description: >-
  Review a document for consequential gaps, contradictions, and missing pieces;
  use bounded delegated analysis, apply authorized corrections, and verify them,
  within a round budget that stops when a round opens more gaps than it closes.
  Use when the user wants to review, audit, polish, or find gaps in a plan, spec, or document.
metadata:
  version: "2.1.1"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep
---

# Plan Gap Review Skill

Analyze consequential gaps and verify authorized corrections. Use `outcome-work`
for compact delegated handoffs and batch decisions. Preserve an explicitly
read-only request: report findings without editing or treating an audit as
authorization to implement new scope.

## Step 1: Identify the Document

The invocation may include a document path. If the user provided one, use it.
Otherwise:

1. Check if there's an obvious document in context (e.g., a plan.md being discussed)
2. Look for common plan/spec files: `**/plan.md`, `**/spec.md`, `**/design.md`, `**/ARCHITECTURE.md`
3. If still unclear, ask the user which document to review and request its path.

Confirm the document exists and read it.

## Step 2: Run Gap Analysis

For substantial documents, delegate a bounded analysis to an available subagent
with minimal context and document paths. Handle small reviews directly. The prompt should:

- Instruct it to read the ENTIRE document
- Look for: contradictions between sections, dangling references, missing cross-references, numbering issues, specification gaps, dead/superseded content, security inconsistencies, UX inconsistencies, ambiguities that block implementation
- For each gap, report: number, category (STRUCTURAL/TECHNICAL/SECURITY/UX/CONSISTENCY), severity (CRITICAL/HIGH/MEDIUM/LOW), location, description, and suggested fix
- Focus on real problems, not cosmetic nitpicks
- Return concise findings with evidence locations; keep exploration out of the
  parent context. Preserve already-settled decisions and acceptance boundaries.

## Step 3: Fix Gaps

Apply corrections covered by the user's authorization. Choose ordinary wording,
references, and implementation details without another question. When a finding
requires a new product decision or scope expansion, collect it with the other
real decisions in one reviewable batch and continue independent authorized fixes.

Use one writer per document. Parallelize independent analysis or edits to disjoint
documents only; never have several fix agents rewrite the same file concurrently.
Give a fix agent the consequential findings, document paths, write scope, and
acceptance checks. Consider alternatives only where there is a real tradeoff;
do not generate an arbitrary number of solutions for each gap. Return changes,
verification evidence, remaining decisions, and the next action.

Keep fixes and their verification on the owning bead. Do not create another bead
or task merely to repeat analysis or record evidence.

## Step 4: Verify and Deliver

Verify the actual corrections and affected references or constraints. Follow any
required repository review gates. Repeat analysis only for changed inputs, a
specific unresolved concern, or a required independent check; do not demand two
identical clean rounds or restart a full review after a cosmetic edit.

**Round budget.** Count, per round, the findings closed and the new findings the
round's own edits introduced, and the document's net line growth. A round that opens
more than it closes is the stop signal: report the state, do not run another. Two
analysis rounds per invocation is the ceiling without changed inputs from outside the
review. Net growth is a finding in itself — a fix that adds a paragraph where a sentence
was missing is a scope addition to batch, not a correction. The legacy tradegraph plan
went through five rounds in one day on 2026-08-21; round two "fixed 23 gaps, most of
them created by round 1". That loop is what this budget ends.

Finish when the authorized consequential findings are resolved and required checks
pass, or report a concrete blocker or exhausted agreed budget. Resolve trivial
in-scope corrections directly; defer low-impact suggestions in the result without
interrupting the user to ask whether to keep reviewing.

Commit and push according to the repository's delivery rules and existing
authorization. Stage only the exact edited paths, preserving other workers' edits.
Update the owning bead with actual verification and any remaining required work.

## Step 5: Report

Return a compact result: consequential findings fixed, verification evidence,
remaining decisions or limitations, and delivery references. Do not paste the
analysis transcript or count extra rounds as evidence of quality.

## Key Principles

- **Bounded context**: Pass the objective, constraints and relevant paths;
  reuse a child's useful context for a focused follow-up.
- **Surgical edits**: Fix agents make targeted edits, not rewrites. Preserve existing content.
- **Outcome ownership**: Keep implementation, verification, and delivery together.
- **No cosmetic nitpicks**: Focus on gaps that would cause implementation confusion, security issues, or user-facing bugs.
- **Rounds are budgeted**: a round that opens more than it closes stops the loop; two rounds per invocation without new outside input; net growth is reported, not hidden.
