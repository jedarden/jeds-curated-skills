# Test Plan Review Report Template

Use this structure when generating the review output.

---

## Test Review Report: [Suite / Plan Name]

**Target:** [test directory and/or test-plan doc path]
**Framework(s):** [pytest / jest / cargo test / go test / ...]
**Reviewed:** [today's date]

---

### Scorecard

| Category | Checks | Present | Partial | Missing |
|---|---|---|---|---|
| 01 Coverage | 8 | | | |
| 02 Failure Handling | 8 | | | |
| 03 Non-Functional | 7 | | | |
| 04 Test Quality | 7 | | | |
| **TOTAL** | **30** | | | |

**Overall health:** [N% present — TRUSTWORTHY / NEEDS WORK / DO NOT TRUST]

---

### Coverage Gaps
*Untested behaviors, ordered by risk. Each row names a concrete behavior and the bug a test would catch.*

| Untested Behavior | Risk if Broken | Suggested Test |
|---|---|---|
| [function/route/branch + input class] | [concrete defect that ships green today] | [the test to add] |
| ... | ... | ... |

---

### Flaky / Weak Tests
*Existing tests that pass for the wrong reason — green through a real regression.*

1. **[test name / file]** — [why it would stay green when the code breaks: over-mocked / vacuous assert / time/random dependence / order coupling]
2. ...

---

### Top Tests to Add
*Ordered by value. The first few are the ones to write today.*

1. **[behavior]** — [what to assert, and the bug it catches]
2. ...
3. ...
4. ...
5. ...

---

### Strengths
*What this suite does well.*

1. ...
2. ...
3. ...

---

### Notes
[Observations about overall test health, framework misuse, or structural issues that
don't fit a single checklist item — e.g. "no failure-injection harness exists at all,"
or "every test shares one module-level DB connection."]
