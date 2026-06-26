# Checklist — Postmortem Quality

The bar a finished postmortem must clear. Rate each: PRESENT / PARTIAL / MISSING.
Any PARTIAL or MISSING gets a one-line note and must be fixed before the document is final.

- [ ] **1.1 Blameless Language**
  Findings target systems and process, never people. No individual named as the cause.
  No name used as blame. Phrasing is "the deploy pipeline allowed X", not "Engineer Y did X".

- [ ] **1.2 No "Human Error" as a Terminal Cause**
  "Human error" or "someone forgot" is never the final answer — it is a prompt to ask
  why the system permitted the mistake. The analysis continues past the human action
  to the missing guardrail.

- [ ] **1.3 Impact Quantified**
  Impact is in numbers, not adjectives. Users affected, duration, SLO/error-budget burn,
  and revenue/cost where applicable. Estimates are allowed but labeled as estimates.

- [ ] **1.4 Detection Captured**
  States how the incident was detected and the time-to-detect. Notes whether the alert
  fired, was actionable, and paged the right people — or that detection was manual.

- [ ] **1.5 Timeline Includes Detection and Every Mitigation Attempt**
  The timeline spans the triggering change through the all-clear. It includes the
  detection event and each mitigation attempt — including the ones that did not work,
  not just the action that finally restored service.

- [ ] **1.6 Analysis Beyond a Single Root Cause**
  The analysis uses a 5-whys or causal chain and names contributing factors beyond one
  root cause. A single-line "root cause: X" with no chain and no contributing factors fails.

- [ ] **1.7 Contributing Factors Named by Category**
  At least the relevant categories from references/CONTRIBUTING-FACTORS.md are considered
  (missing guardrail, alerting gap, insufficient testing, unclear ownership, knowledge silo,
  fragile rollback) and the applicable ones are named explicitly.

- [ ] **1.8 What Went Well Present**
  The response's strengths are named, not just its failures. Fast detection, clean rollback,
  good comms — so they are reinforced and survive.

- [ ] **1.9 Where We Got Lucky Present**
  A dedicated section names the near-misses — what made this smaller than it could have been
  and would not hold next time.

- [ ] **1.10 Action Items Have Owner + Due Date + Type**
  Every action item names an owner, a due date, and is classified prevent / detect / mitigate.
  Rows missing any of the three fail.

- [ ] **1.11 No "Be More Careful" Action Items**
  No action item is "be more careful", "pay closer attention", "remember to", or any
  un-verifiable behavioral exhortation. Each is a concrete system or process change.

- [ ] **1.12 Lessons Generalize**
  Lessons learned are durable takeaways that apply beyond this one incident — not a restated
  summary of what happened.
