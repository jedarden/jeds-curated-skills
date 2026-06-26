# API Design Review Report Template

Use this structure when generating the review output.

---

## API Design Review: [API / Service Name]

**API Style:** [REST / gRPC / GraphQL / CLI]
**Reviewed:** [today's date]
**Definition:** [file path(s)]
**Surface size:** [N operations / RPCs / types / commands]

---

### Scorecard

| Category | Checks | Present | Partial | Missing | N/A |
|---|---|---|---|---|---|
| 01 Resource Modeling | 10 | | | | |
| 02 Method Semantics | 10 | | | | |
| 03 Versioning & Compat | 10 | | | | |
| 04 Payloads & Formats | 11 | | | | |
| 05 Security & Limits | 10 | | | | |
| **TOTAL** | **51** | | | | |

**Overall health:** [N% present — READY TO LOCK / NEEDS WORK / NOT READY]

---

### Critical Issues
*MISSING/PARTIAL items that will force a breaking change or v2 if shipped as-is. Fix before the contract is locked.*

1. **[Item ID] [Name]** — [What's wrong, the offending operation/field, and the anti-pattern it matches]
2. ...

---

### Items Needing Strengthening
*PARTIAL items — handled inconsistently or underspecified.*

1. **[Item ID] [Name]** — [Which operations are inconsistent and what the canonical fix is]
2. ...

---

### Strengths
*What this API does well.*

1. ...
2. ...
3. ...

---

### Recommended Next Steps
*Ordered by how expensive the fix becomes after clients integrate.*

1. **[Highest blast-radius fix]** — [Specific change to the spec/schema]
2. ...
3. ...
4. ...
5. ...

---

### Notes
[Overall observations about consistency, style, or unusual choices that don't fit a single
checklist item — e.g. mixed casing conventions, partial REST/RPC hybrid, etc.]
