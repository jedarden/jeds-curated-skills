# Runbook: Large Diff Review

Use when the collected diff exceeds ~800 changed lines. A single reviewer pass over a large diff
loses precision — context falls out of view and findings drift. Chunk, parallelize, then dedup.

---

## Step 1: Partition the Diff

Split the diff into chunks that each fit comfortably in a reviewer's context (~300–500 changed
lines). Partition along natural seams so each chunk is self-contained:

- **By file** first — keep each file's hunks together.
- **By hunk** for any single file larger than a chunk — split at function/class boundaries, never
  mid-function.
- Group small related files (same module/directory) into one chunk to preserve cross-file context.

Record which files/hunks went into which chunk so nothing is dropped or double-counted.

## Step 2: Parallel Reviewers

Spawn one `diff-reviewer` subagent per chunk. Give each:
1. Its chunk of the diff.
2. The changed-files summary for the whole diff (so it knows what else moved).
3. All four checklist files.

Each reviewer may read files directly for context beyond its chunk, but only emits findings whose
**cited line falls inside its own chunk** — this prevents two reviewers reporting the same issue.

## Step 3: Merge & Dedup Candidates

Collect all candidate findings. Deduplicate:
- Same `file:line` + same checklist item → keep one (the one with the more concrete mechanism).
- A cross-cutting issue that appears in many chunks (e.g. the same unsafe pattern repeated) →
  collapse into a single finding that lists the representative location plus the count of others.

## Step 4: Single Verification Pass

Run ONE `finding-verifier` subagent over the deduplicated candidate list against the full diff.
Verifying centrally (not per-chunk) keeps the false-positive bar uniform across the whole review.

## Step 5: Report

Emit the standard `REPORT-TEMPLATE.md` report from the surviving findings. In the Notes section,
record the chunking (how many chunks, how partitioned) so the scope of the review is auditable.

---

## Guardrails

- Never let a reviewer emit findings outside its assigned chunk — overlap creates duplicates.
- Keep the precision-first bias: a large diff is not license to produce more findings, only to
  cover more ground without losing context.
- If a chunk is itself noisy with low-confidence candidates, that is expected — the single
  verification pass is what removes them.
