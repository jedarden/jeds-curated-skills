# Release Readiness Report Template

Use this structure when generating the go/no-go output.

---

## Release Readiness Report: [version / ref]

**Release Type:** [Standard / Hotfix]
**Evaluated:** [today's date]
**Range:** [last tag] -> [target ref]  ([N commits, M files changed])
**Working tree:** [clean / DIRTY]

---

### Verdict: **[GO / CONDITIONAL / NO-GO]**

[One sentence stating the verdict and the single most important reason for it.]

---

### Gate Scorecard

| Checklist | Gates | Present | Partial | Missing |
|---|---|---|---|---|
| 01 Quality Gates | 8 | | | |
| 02 Versioning | 6 | | | |
| 03 Operations | 6 | | | |
| 04 Comms & Docs | 5 | | | |
| **TOTAL** | **25** | | | |

---

### Blocking Items
*Must be resolved before shipping. A non-empty list means NO-GO (or CONDITIONAL if every item here is non-critical).*

1. **[Gate ID] [Name]** — [What evidence was missing] -> [Concrete action that clears it]
2. ...

*(If empty: "None — no blocking gates outstanding.")*

---

### Non-Blocking Warnings
*PARTIAL gates and non-critical MISSING gates. Will not stop the release but should be tracked.*

1. **[Gate ID] [Name]** — [What is insufficient]
2. ...

---

### Evidence Highlights
*What was verified, and how. Cite the file path, command, or CI run for each.*

1. **[Gate ID]** — [evidence: file / command / CI run]
2. ...
3. ...

---

### Recommended Pre-Release Actions
*Ordered by impact. Clear the blocking items first.*

1. **[Highest-priority blocker]** — [specific action]
2. ...
3. ...

---

### Notes
[Anything about the release that does not fit the gates — unusual scope, risky timing,
dirty tree, a hotfix path taken, etc.]
