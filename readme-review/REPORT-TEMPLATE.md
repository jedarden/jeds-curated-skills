# README Review Report Template

Use this structure when generating the review output.

---

## README Review Report: [Project Name]

**Project Type:** [Library / CLI / Service / Application]
**Reviewed:** [today's date]
**Document:** [file path]

---

### Scorecard

| Category | Checks | Present | Partial | Missing |
|---|---|---|---|---|
| 01 Orientation | 7 | | | |
| 02 Getting Started | 7 | | | |
| 03 Reference | 7 | | | |
| 04 Maintenance | 8 | | | |
| **TOTAL** | **29** | | | |

**Overall health:** [N% present — READY / NEEDS WORK / NOT READY]

---

### Zero-to-Running Gap Analysis
*Can a stranger install and run this project from the README alone? The single most
important verdict in this report.*

**Verdict:** [YES / NO / ONLY WITH GUESSWORK]

**Blocking gaps** (steps a newcomer cannot complete from the README):
1. [Step / command] — [what is missing: undocumented config, unset env var, skipped build...]
2. ...

**Unverifiable commands** (could not confirm these are complete):
1. `[command]` — [why it could not be verified]
2. ...

---

### Missing Sections
*MISSING items, in priority order. Orientation and Getting Started gaps come first.*

1. **[Item ID] [Name]** — [One sentence on what's absent and why it matters for this type]
2. ...

---

### Items Needing Strengthening
*PARTIAL items — present but insufficient.*

1. **[Item ID] [Name]** — [What specifically is incomplete in the current version]
2. ...

---

### Strengths
*What this README does well.*

1. ...
2. ...
3. ...

---

### Quick Wins
*Cheap fixes with high payoff — ordered by impact-per-effort.*

1. **[Fix]** — [Specific action, e.g. "Add an `npm install` block above the API section"]
2. ...
3. ...

---

### Notes
[Any observations about the README's overall quality, tone, or unusual characteristics
that don't fit neatly into the checklist framework.]
