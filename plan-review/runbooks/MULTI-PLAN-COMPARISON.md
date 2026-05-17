# Runbook: Multi-Plan Comparison

Use when comparing two plans for the same project (e.g., Opus vs. GPT version,
v1 vs. v2, or two competing architectural approaches).

---

## Context

Multiple plans for the same system surface design disagreements and coverage gaps
that neither plan alone would reveal. The comparison is more valuable than reviewing either alone.

---

## Process

### Step 1: Run Score on Both Plans

```bash
~/.claude/skills/plan-review/scripts/score-plan.sh plan-a.md
~/.claude/skills/plan-review/scripts/score-plan.sh plan-b.md
```

### Step 2: Header Diff

```bash
~/.claude/skills/plan-review/scripts/scan-headers.sh plan-a.md > /tmp/headers-a.txt
~/.claude/skills/plan-review/scripts/scan-headers.sh plan-b.md > /tmp/headers-b.txt
diff /tmp/headers-a.txt /tmp/headers-b.txt
```

### Step 3: Identify Unique Coverage in Each

- What does Plan A address that Plan B ignores?
- What does Plan B address that Plan A ignores?
- Where do they contradict each other?
- Where do they agree (strong signal — these decisions are likely correct)?

### Step 4: Extract the Best of Both

For each section category, determine which plan's treatment is better:
- More specific? More actionable? More realistic?

### Step 5: Produce Synthesis Recommendation

Output a merged section list: "take section X from Plan A, section Y from Plan B,
draft new section Z because neither covered it."

---

## Output Format

```
## Multi-Plan Comparison: [Plan A] vs [Plan B]

### Scores
- Plan A: N/M (N%)
- Plan B: N/M (N%)

### Unique to Plan A (missing from Plan B)
- ...

### Unique to Plan B (missing from Plan A)
- ...

### Contradictions (must resolve)
1. [Topic]: Plan A says X, Plan B says Y — Recommendation: [which to follow and why]
...

### Agreement (high confidence decisions)
- ...

### Synthesis Recommendation
For a merged plan:
- Take from Plan A: [sections]
- Take from Plan B: [sections]
- Draft new: [sections neither covered]
```
