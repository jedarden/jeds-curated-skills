# Spec Review Report Template

Use this structure when generating the review output.

---

## Spec Review Report: [Document Name]

**Reviewed:** [today's date]
**Document:** [file path]

---

### Scorecard

| Category | Checks | Present | Partial | Missing |
|---|---|---|---|---|
| 01 Clarity | 8 | | | |
| 02 Testability | 7 | | | |
| 03 Completeness | 9 | | | |
| 04 Constraints | 7 | | | |
| **TOTAL** | **31** | | | |

**Overall health:** [N% present — READY FOR PLANNING / NEEDS TIGHTENING / NOT READY]

---

### Ambiguity Table
*Every vague phrase, quoted verbatim, with a precise rewrite. Find-and-replace these.*

| Quoted Phrase | Problem | Suggested Rewrite |
|---|---|---|
| "[exact text from spec]" | [item ID + why it's ambiguous] | [concrete, testable replacement] |
| ... | ... | ... |

---

### Untestable & Missing Requirements
*Requirements with no observable acceptance condition, plus absent non-functional areas.
Ordered by impact on the downstream plan.*

1. **[Item ID] [Name]** — [What's missing or untestable and why it matters to planning]
2. ...

---

### Clarifying Questions to Send Back
*Sharp, closed-ended questions the spec author must answer before a plan can be written.*

1. [Question requiring a specific number, scope call, or decision]
2. ...

---

### Strengths
*What this spec does well.*

1. ...
2. ...
3. ...

---

### Recommended Next Steps
*Ordered by impact. Address before handing to plan-author.*

1. **[Highest priority gap]** — [Specific action]
2. ...
3. ...

---

### Notes
[Observations about the spec's overall quality or style that don't fit the checklist.]
