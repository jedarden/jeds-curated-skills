# Plan Review Memo — template

A memo, not a scorecard. Verdict first; every finding carries its proposed answer and a
`file:line` anchor; appendices hold the tables. Keep the body under ~2 pages for a typical
plan — if it is longer, the findings are not ranked hard enough.

Save to `docs/notes/plan-review-<YYYY-MM-DD>.md` (plan at `docs/plan/plan.md`) or
`<plan-dir>/<plan-basename>-review-<YYYY-MM-DD>.md`.

---

```markdown
# Plan Review: <plan title>

**Verdict:** NOT READY · READY AFTER DECISIONS (n) · READY
**Plan:** `<path>` @ `<git sha · date>` · **Type:** <Greenfield / Port / Improvement / Integration / Migration / Spike> · **Code exists:** yes/no
**Reviewed:** <YYYY-MM-DD> by plan-review 2.0

<One plain paragraph. Why this verdict. The single biggest risk in one sentence. If READY
AFTER DECISIONS: "Answer the n questions below and this plan can be decomposed and built
without an ADR." If NOT READY: name the cap and what fixing it takes.>

**Next action:** `/plan-review --lock all` · `/plan-review --lock DN-1,DN-3` · fix Cap Cn first

---

## 1. Decide these now

<Ordered by stakes × proximity. One block per DN. Omit the section if there are none.>

### DN-1 · <fork name> — <DEFERRED / UNNOTICED / SHADOW / ASSERTED> · stakes <H/M/L> · first needed: Phase <n>
**Where:** `plan.md:28`, `plan.md:118` · **Plan says:** "<quote, ≤1 line>" (or: nothing)
**Why it matters:** <the concrete incident this becomes — in this system's terms, not generically>
**Proposed decision:** <choice>.
**Because:** <…> **Rejected:** <alt> — <why>. **Enforced by:** <test / gate / invariant>. **Revisit if:** <signal>.
**To lock:** `/plan-review --lock DN-1`

### DN-2 · …

## 2. First questions an implementer hits (dry run)

**Phase <0|1> walk.** <Two to five sentences of narrative: "I create `cmd/x/main.rs`; the first
thing I need is the config precedence — the plan lists env vars but not which wins…">
- Q1 <question> → DN-3
- Q2 <question> → reality check R2
- …

**Riskiest later phase (<n>).** <Same, shorter.>

**Fleet test:** <passes / fails — which bead would require a design call, and which DN or
human gate resolves it>

## 3. Reality check & contradictions

| # | Claim | Where | Result | Note |
|---|---|---|---|---|
| R1 | "<claim about existing code/cluster/library>" | `plan.md:74` | VERIFIED / FALSE / UNVERIFIABLE-FROM-HERE | <how checked, read-only> |

**Contradictions:**
- `plan.md:63` says <X>; `plan.md:214` says <Y>. → <which should win and why> (→ DN-n if a decision)

**Freshness:** <date stamp present? last updated vs. last code change?>

## 4. Safety caps

| Cap | Result | Evidence |
|---|---|---|
| C1 observable acceptance for the central outcome | pass / **TRIPPED** | `plan.md:…` |
| C2 destructive steps have backup + rollback + trigger | pass / TRIPPED / n/a | |
| C3 bounded first slice exists | | |
| C4 no high-stakes open fork on Phase 0–1's path | | → DN-n |
| C5 load-bearing claims hold | | → R-n |
| C6 house rules respected | | <rule + line> |
| C7 secrets / untrusted input policy stated | | |

## 5. Structural gaps that apply

<Only applicable MISSING / PARTIAL. One line each. Items that reduce to a DN are listed as
"→ DN-n", not repeated.>
- **4.1 Edge case catalog — MISSING.** No catalogue; three edge cases are mentioned inline at `:28`, `:33`, `:41`. Start there.
- **5.2 Completion criteria — PARTIAL.** Phases 1–7 are checkboxes; only Phase 7 has acceptance criteria (`:104`).

## 6. What this plan gets right

<Three to five, specific enough to be reused as exemplars: "Infrastructure section decides
cluster, namespace, storage class, exposure, and secret path with a reason each (`:66–80`)
— that is six forks locked in fifteen lines.">

---

## Appendix A — Decision ledger

| # | Fork (catalog §) | State | Stakes | First needed | Where | Note |
|---|---|---|---|---|---|---|
| 1 | Language / runtime (1.1) | ASSERTED | H | P1 | `:38` | "Rust, likely axum" — language fine, framework hedged → DN-4 |
| 2 | Source of truth (2.1) | LOCKED | H | P3 | `:20` | JSONL before SQLite; rebuild path named |
| … | | | | | | |

## Appendix B — Structural sweep

| ID | Item | Rating | Note |
|---|---|---|---|
| 1.1 | North star | PRESENT | `:5` |
| 1.2 | Non-goals with rationale | PARTIAL | "no Twitter semantics" stated; rationale present; nothing else excluded |
| … | | | |
| 7.6 | Threat matrix | N/A | internal, tailnet-only, one caller |
```

---

## Style rules for the memo

- Lead with the verdict and the paragraph. A reader who stops there knows what to do.
- Every DN has a proposed decision. A finding without a proposal is a complaint; this is a review.
- Quote the plan, anchor the line. `plan.md:118` is clickable; "the infrastructure section" is not.
- Name the incident, not the category. "Front-page queries cached forever → client reports 0 new
  tweets for nine days" beats "cache staleness risk".
- No percentages, no "N of 83". Counts of DNs and caps are the only numbers in the header.
- N/A is a rating. Do not list the threat matrix a 150-line CLI plan does not need.
- Strengths are specific enough to copy. "Good structure" is not a strength.
- The memo is written to disk before it is summarised in chat.
