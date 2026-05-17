# Runbook: Quick Triage (5-Minute Pre-Review)

Use when you need a fast signal on plan readiness without a full review.
Output is a go/no-go recommendation, not a detailed report.

---

## When to Use

- Before deciding whether to invest in a full review
- When a plan is very short (<200 lines) and clearly incomplete
- When you need a quick answer: "is this safe to start implementing?"

---

## Process

### Step 1: Run the Score Script

```bash
~/.claude/skills/plan-review/scripts/score-plan.sh <plan-file>
```

If score < 40%, output: **NOT READY — full review unnecessary, plan needs fundamental work first.**

### Step 2: Check the 5 Critical Items

These 5 items predict 80% of in-flight pivots. If any are MISSING, flag immediately:

1. **Acceptance Scenarios** — `grep -i "scenario\|pass criteria\|user does" <plan-file>`
2. **Non-Goals** — `grep -i "non.goal\|out of scope\|not a goal" <plan-file>`
3. **Failure Modes** — `grep -i "failure mode\|what if.*fails\|error.*recovery" <plan-file>`
4. **Phase Completion Criteria** — `grep -i "done when\|completion criteria\|exit criteria" <plan-file>`
5. **Risk Register** — `grep -i "risk register\|likelihood\|mitigation" <plan-file>`

### Step 3: Output

```
Quick Triage: <filename>
Score: N% (N/M checks passed)

Go/No-Go: [GO / NO-GO / CAUTION]

Critical missing items:
- [item] (predicted pivot: [pivot type from PIVOT-CAUSES.md])

Recommendation: [start full review / fix fundamentals first / safe to implement]
```

---

## Decision Matrix

| Score | Critical Items Missing | Recommendation |
|-------|----------------------|----------------|
| ≥80%  | 0                    | GO — safe to implement |
| ≥80%  | 1–2                  | CAUTION — fix critical items first |
| 60–79%| 0–1                  | CAUTION — run full review |
| 60–79%| 2+                   | NO-GO — fix fundamentals |
| <60%  | any                  | NO-GO — plan needs significant work |
