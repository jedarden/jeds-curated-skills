# Runbook: comparing two plans for one system

Two drafts (two models, v1 vs. v2, two architectures) disagree in ways neither reveals alone.
Compare the **ledgers**, not the headers: where the plans *decide differently* is where the
design risk is; where they agree is the strongest signal either is right.

## Process

1. **Build a ledger for each** (SKILL.md Step 3), using the same fork numbering from
   `references/DECISION-LEDGER.md` so rows align.
2. **Join on fork.** For each fork: A's state and choice · B's state and choice.
3. **Classify each row:**
   - **Agree, both LOCKED** — high confidence; carry into the merged plan as is.
   - **Agree on choice, one has rationale** — take the locked one's text.
   - **Disagree** — the real design question. Write a DN with *both* choices as options
     (Form 2) and propose one, with the reason the other loses.
   - **Only one noticed the fork** — take it; note that the other plan was silent.
   - **Neither noticed** — UNNOTICED in both; propose from the catalog.
4. **Caps for each** — a plan that trips a cap loses that section regardless of polish.
5. **Synthesis:** section by section, which plan's treatment survives, and the DN list the
   merged plan still carries.

## Output

```markdown
## Plan comparison: <A> vs <B>

Caps: A — none · B — C3 (no first slice)

| Fork | A | B | Take | Why |
|---|---|---|---|---|
| 1.1 language | LOCKED Go | LOCKED Go | A | same choice; A has rationale + fallback |
| 2.2 storage | ASSERTED SQLite | LOCKED Postgres | **DN-1** | genuine disagreement; propose SQLite — single writer, §6.3 |
| 2.7 staleness | — | LOCKED per-shape TTL | B | A silent |
| 6.1 first slice | LOCKED | MISSING | A | B trips C3 |

### Decisions the merged plan still needs
DN-1 … (Form 1 proposal)

### Synthesis
Take from A: §§1–3, 6, 9. Take from B: §7 data model, staleness rule. Draft new: rollback (neither had it).
```

Header diffs (`scan-headers.sh` on both) are a useful *locator* for sections one plan lacks,
but a section present in both can still decide nothing — the ledger is the comparison.
