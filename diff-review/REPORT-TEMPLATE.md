# Diff Review Report Template

Use this structure when generating the review output. Include only findings that survived
adversarial verification (CONFIRMED). Order groups Blocking, then Should-fix, then Nit.

---

## Diff Review Report

**Base ref:** [resolved base — e.g. merge-base with origin/main, or staged / working-tree]
**Reviewed:** [today's date]
**Changed files:** [N files, +A / -D lines]

---

### Verdict

**[approve | approve-with-nits | request-changes]** — [one sentence justification]

- `request-changes` if any Blocking finding survived.
- `approve-with-nits` if only Should-fix / Nit findings survived.
- `approve` if no findings survived.

---

### Blocking
*Bugs that produce wrong results, crashes, leaks, corruption, or clear vulnerabilities. Fix before merge.*

1. **`file:line`** — [concrete mechanism: the input/condition that triggers it and the wrong result.]
   **Fix:** [minimal concrete change.]
2. ...

*(Write "None." if empty.)*

---

### Should-fix
*Real design, cleanup, or test-coverage problems. Address before merge or file a follow-up.*

1. **`file:line`** — [what's wrong and why it matters.]
   **Fix:** [concrete change.]
2. ...

*(Write "None." if empty.)*

---

### Nits
*Minor, optional. Listed only because they are clearly correct.*

1. **`file:line`** — [observation.] **Fix:** [optional change.]
2. ...

*(Write "None." if empty.)*

---

### Notes
[Optional: scope caveats, files skipped, areas not reviewable from the diff alone, or why the
diff was clean. Omit if there is nothing material to add.]
