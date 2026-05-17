# Runbook: Stale Plan Review

Use when reviewing a plan for a project that is already mid-implementation.
The normal pre-flight checklist applies, but with these modifications.

---

## Context

A stale plan is one where implementation has already begun. The goal shifts from
"prevent pivots" to "diagnose why we're pivoting and prevent further ones."

---

## Modified Process

### Step 1: Establish Ground Truth

Before running the normal checklist, determine the implementation state:

```bash
# In the project repo
git log --oneline -20        # Recent commits
git status                   # Uncommitted changes
find . -name "*.md" | xargs grep -l "TODO\|FIXME\|HACK" 2>/dev/null
```

Note: what phases are complete, what is in progress, what hasn't started.

### Step 2: Check for Plan Drift

Compare the plan's stated architecture against what was actually built:

- Do the component names in the plan match the code?
- Do the data model definitions match the actual schema?
- Are the phase completion criteria reflected in git history?
- Are there modules in the code not described in the plan?

### Step 3: Identify Active Pivots

Look for signals that a pivot is already happening:
- TODOs that contradict the plan
- Code comments saying "originally this was supposed to..."
- Large uncommitted refactors
- Feature branches that add things marked as non-goals

### Step 4: Run Normal Checklist With Adjusted Ratings

For each checklist item, rate with stale-plan context:
- **PRESENT** = adequately addressed in plan AND reflected in implementation
- **PARTIAL** = addressed in plan but implementation diverged, or vice versa
- **MISSING** = absent from plan and not in implementation either

### Step 5: Produce Gap Analysis for Remaining Work

The report should focus on: what is still unimplemented that lacks plan coverage?
These are the highest-risk areas for the remaining work.

---

## Triage Priority for Stale Plans

1. **Active divergences** (plan says X, code does Y) — must reconcile before proceeding
2. **Unplanned territory** (code entering areas the plan didn't address) — plan it now
3. **Missing pre-flight items for incomplete phases** — apply normal checklist to phases not started
4. **Clean up** — everything else

---

## Output Additions for Stale Plans

Add a section to the normal report:

```
## Stale Plan Analysis

**Implementation state:** Phase N of M complete
**Active divergences:** N items where code contradicts plan
**Unplanned territory:** N code areas not covered by plan

### Divergences (reconcile before continuing)
1. [Plan says X, code does Y] — Recommended: update plan OR revert code
...

### Unplanned Territory (add to plan now)
1. [Area]: [what the code is doing that wasn't planned]
...
```
