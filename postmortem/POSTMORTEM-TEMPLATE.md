# Incident Postmortem Template

Fill every section. A section with no content is a finding in itself — say so explicitly
(e.g. "No alert fired; detection was manual") rather than deleting the heading.

---

# Postmortem: [Short Incident Title]

**Severity:** [SEV1 / SEV2 / SEV3 — define your own scale, but state the impact tier]
**Date of incident:** [YYYY-MM-DD]
**Author:** [role or team, not a single name to blame]
**Status:** [Draft / Reviewed / Final]

---

## Summary

One paragraph, plain language. What broke, what users experienced, how long it lasted,
and how it was resolved. A reader should understand the whole incident from this paragraph
alone. No jargon, no blame.

---

## Impact

Quantify everything known. Estimate and label estimates as estimates.

- **Users affected:** [count or percentage, and how — errors, slowness, data loss]
- **Duration:** [start → end, total minutes/hours of user-facing impact]
- **SLO / error budget:** [budget consumed, e.g. "burned 40% of monthly availability budget"]
- **Revenue / cost:** [if applicable — failed transactions, refunds, lost orders; estimate]
- **Data integrity:** [any data lost, corrupted, or requiring backfill]

---

## Detection

- **How detected:** [automated alert / customer report / engineer noticed / dashboard]
- **Time to detect (TTD):** [incident start → first human aware]
- **Was the alert adequate?** [did it fire, was it actionable, did it page the right people]

---

## Timeline

All times in [TZ]. Timestamped events from first contributing cause through full resolution.
Include the triggering change, the first symptom, detection, every mitigation attempt
(including the ones that did not work), and the all-clear.

| Time | Event |
|------|-------|
| HH:MM | [Triggering change deployed / config pushed / dependency changed] |
| HH:MM | [First symptom — what the system did] |
| HH:MM | [Detection — alert fired / report received] |
| HH:MM | [First responder engaged] |
| HH:MM | [Mitigation attempt 1 — and its result] |
| HH:MM | [Mitigation attempt 2 — and its result] |
| HH:MM | [Action that actually restored service] |
| HH:MM | [Service confirmed healthy / all-clear] |

---

## Root Cause and Contributing Factors

Lead with the causal chain, not a single line. Use a 5-whys or a causal narrative.
An incident of any size almost always has more than one contributing factor — name them.

**Triggering cause:** [the immediate technical trigger]

**Causal chain / 5-whys:**
1. Why did users see errors? → ...
2. Why did that happen? → ...
3. Why was that possible? → ...
4. Why did nothing stop it earlier? → ...
5. Why was the system in a state where this could occur? → ...

**Contributing factors:** [list each — e.g. missing guardrail, alerting gap,
insufficient test coverage, unclear ownership, knowledge silo, fragile rollback.
See references/CONTRIBUTING-FACTORS.md]

---

## What Went Well

The response is not all failure. Name what worked — fast detection, a clean rollback,
good runbook, effective communication. Reinforce these so they survive.

- ...
- ...

---

## What Went Poorly

Systemic and process gaps in the response. Phrase blamelessly — the gap is in the system,
not the person who hit it.

- ...
- ...

---

## Where We Got Lucky

The near-misses. What made this incident smaller than it could have been, and would not
hold next time. These are future incidents waiting to happen if not addressed.

- ...
- ...

---

## Action Items

Every row needs an owner, a due date, and a type. Type is **prevent** (stop the cause
recurring), **detect** (catch it faster next time), or **mitigate** (reduce blast radius
when it does recur). No "be more careful" items — each must be a concrete, verifiable change.

| Action Item | Type | Owner | Due Date | Tracking ID |
|-------------|------|-------|----------|-------------|
| [Concrete change] | prevent | [role/team] | [YYYY-MM-DD] | [ticket id] |
| [Concrete change] | detect | [role/team] | [YYYY-MM-DD] | [ticket id] |
| [Concrete change] | mitigate | [role/team] | [YYYY-MM-DD] | [ticket id] |

---

## Lessons Learned

Durable takeaways that generalize beyond this one incident — assumptions that proved
false, mental models that need updating, patterns to watch for elsewhere in the system.

- ...
- ...
