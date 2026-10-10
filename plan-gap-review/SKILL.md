---
name: plan-gap-review
version: 2.0.0
description: >-
  Review a document for consequential gaps, contradictions, and missing pieces;
  use bounded delegated analysis, apply authorized corrections, and verify them.
  Use when the user wants to review, audit, polish, or find gaps in a plan, spec, or document.
argument-hint: "[path/to/document.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion
---

# Plan Gap Review Skill

Analyze consequential gaps and verify authorized corrections. Use `outcome-work`
for compact delegated handoffs and batch decisions. Preserve an explicitly
read-only request: report findings without editing or treating an audit as
authorization to implement new scope.

## Step 1: Identify the Document

If the user provided a file path as an argument, use that. Otherwise:

1. Check if there's an obvious document in context (e.g., a plan.md being discussed)
2. Look for common plan/spec files: `**/plan.md`, `**/spec.md`, `**/design.md`, `**/ARCHITECTURE.md`
3. If still unclear, use AskUserQuestion to ask: "Which document should I review? Provide the file path."

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
