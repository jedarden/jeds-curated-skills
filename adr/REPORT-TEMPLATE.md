# ADR Review Report Template

Use this structure when generating review output. One report per ADR; for a directory, add the
directory-level summary at the end.

---

## ADR Review Report: [NNNN — Title]

**Document:** [file path]
**Status:** [Proposed / Accepted / Deprecated / Superseded]
**Reviewed:** [today's date]

---

### Scorecard

| # | Item | Rating |
|---|---|---|
| 1.1 | Title is a decision, not a topic | |
| 1.2 | Status present and lifecycle-correct | |
| 1.3 | Date present and meaningful | |
| 1.4 | Context states the forces | |
| 1.5 | Decision is specific and actionable | |
| 1.6 | >=2 real alternatives genuinely weighed | |
| 1.7 | Each alternative has a specific "why not" | |
| 1.8 | Consequences include the negatives | |
| 1.9 | Follow-on work identified | |
| 1.10 | Reversibility / blast radius noted | |
| 1.11 | Supersession links maintained | |
| 1.12 | Scoped to one decision | |

**Tally:** [N PRESENT / N PARTIAL / N MISSING]
**Overall:** [STRONG / NEEDS WORK / WEAK]

---

### Weaknesses
*Ordered by severity. Lead with strawman alternatives and missing negatives — the two ways ADRs lie.*

1. **[Item ID] [Name]** — [What is wrong, named specifically. For strawmen, name the alternative.
   For missing negatives, name the omitted cost.]
2. ...

---

### Strengths
*What this ADR does well.*

1. ...
2. ...

---

### Suggested Strengthenings
*Concrete edits that would raise the rating. Ordered by impact.*

1. **[Item ID]** — [Specific addition or rewrite.]
2. ...

---

### Directory Summary
*(Only when reviewing a directory of ADRs.)*

| ADR | Overall | Top weakness |
|---|---|---|
| NNNN — ... | | |

**Broken supersession chains:** [list any one-directional or dangling Supersedes/Superseded-by links, or "none"]

**Notes:** [staleness, duplicated decisions across ADRs, numbering gaps, or other cross-cutting observations]
