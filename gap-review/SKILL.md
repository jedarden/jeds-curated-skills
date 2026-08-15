---
name: gap-review
version: 1.0.0
description: >-
  Iteratively review a document for gaps, contradictions, and missing pieces. Spawns agents
  to brainstorm 20 solutions per gap, picks the best, applies fixes, and re-analyzes.
  Use when the user wants to review, audit, polish, or find gaps in a plan, spec, or document.
argument-hint: "[path/to/document.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion
---

# Gap Review Skill

Iteratively analyze a document for gaps, contradictions, inconsistencies, and missing pieces. For each gap found, brainstorm 20 solutions and apply the best one. Re-analyze after fixes until clean.

## Step 1: Identify the Document

If the user provided a file path as an argument, use that. Otherwise:

1. Check if there's an obvious document in context (e.g., a plan.md being discussed)
2. Look for common plan/spec files: `**/plan.md`, `**/spec.md`, `**/design.md`, `**/ARCHITECTURE.md`
3. If still unclear, use AskUserQuestion to ask: "Which document should I review? Provide the file path."

Confirm the document exists and read it.

## Step 2: Run Gap Analysis

Spawn an Agent with subagent_type "general-purpose" to analyze the document with fresh eyes. The agent prompt should:

- Instruct it to read the ENTIRE document
- Look for: contradictions between sections, dangling references, missing cross-references, numbering issues, specification gaps, dead/superseded content, security inconsistencies, UX inconsistencies, ambiguities that block implementation
- For each gap, report: number, category (STRUCTURAL/TECHNICAL/SECURITY/UX/CONSISTENCY), severity (CRITICAL/HIGH/MEDIUM/LOW), location, description, and suggested fix
- Focus on real problems, not cosmetic nitpicks

## Step 3: Fix Gaps

If gaps are found, batch them into groups of 5 and spawn fix agents in parallel. Each fix agent:

- Receives the gap descriptions plus the document path
- For each gap: brainstorms 20 clever solutions, ranks by alignment with the document's overarching goal, picks the top solution
- Applies the fix directly to the document via Edit tool
- Reports what was changed

Use TaskCreate to track each batch. Mark tasks as completed when done.

## Step 4: Re-Analyze (Loop)

After all fixes are applied:
1. Commit the changes with a descriptive message listing all gaps fixed
2. Increment the round counter
3. Go back to Step 2 with a fresh analysis agent

Continue looping until:
- A round finds 0 gaps, OR
- A round finds only LOW severity gaps (ask user if they want to continue), OR
- 5 rounds have been completed (diminishing returns)

## Step 5: Report

After the final round, summarize:
- Total gaps found and fixed across all rounds
- Breakdown by category and severity
- Any remaining open items or known limitations
- Final document line count

## Key Principles

- **Fresh eyes**: Every analysis agent starts with no prior context. It reads the document cold.
- **20 solutions per gap**: Don't take the obvious fix. Brainstorm 20 approaches, rank by how well they serve the document's goal, pick the best.
- **Surgical edits**: Fix agents make targeted edits, not rewrites. Preserve existing content.
- **Commit per round**: Each round's fixes are committed separately for traceability.
- **No cosmetic nitpicks**: Focus on gaps that would cause implementation confusion, security issues, or user-facing bugs.
