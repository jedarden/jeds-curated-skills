# Contributing-Factor Categories

Use this list to push analysis past the single triggering cause. For each incident, walk
the categories and ask "did this play a part?" Most incidents touch three or more. Naming
the category points straight at the type of action item that fixes it.

---

## Missing Guardrail
A risky operation had no automated check, gate, or constraint preventing the bad outcome.
- Symptoms: a single command, config value, or deploy could cause harm with nothing in the way.
- Examples: no migration-before-deploy gate; no range validation on a config field;
  destructive command with no confirmation or dry-run; no canary before full rollout.
- Fixes toward: **prevent** action items (validation, gates, canaries, required dry-run).

## Alerting / Detection Gap
The problem was real before anyone knew. No alert fired, the alert was not actionable,
or it paged the wrong people.
- Symptoms: long time-to-detect; detection via customer report or by chance.
- Examples: no alert on the failing metric; alert threshold too loose; alert fired but to
  a channel no one watches; symptom not instrumented at all.
- Fixes toward: **detect** action items (new alerts, tighter thresholds, better routing, SLO burn alerts).

## Insufficient Testing
The failure path existed in production but was untested or untestable.
- Symptoms: an edge case, empty input, or error path that no test exercised.
- Examples: no coverage for the empty-payload case; no integration test across the two
  services that disagreed; load not tested at production scale; no failure-injection test.
- Fixes toward: **prevent** action items (add the missing test, add a test gate to CI).

## Unclear Ownership
No one was clearly responsible for the failing component, the alert, or the decision,
so response was slow or fell between teams.
- Symptoms: time lost figuring out who owns this; the component had no on-call.
- Examples: shared service with no named owner; alert with no runbook and no owning team;
  a dependency owned by a team that did not know it was in the critical path.
- Fixes toward: **mitigate** and **detect** action items (assign ownership, add to on-call rotation).

## Knowledge Silo
The information needed to diagnose or fix lived in one person's head or was undocumented.
- Symptoms: response stalled until a specific person was reached; "only X knows how this works".
- Examples: no runbook for the failing system; recovery steps undocumented; tribal knowledge
  about a quirk that caused the incident.
- Fixes toward: **mitigate** action items (write the runbook, document the system, cross-train).

## Fragile / Slow Rollback
Recovery was harder, slower, or riskier than it should have been.
- Symptoms: rollback made things worse, was not a known-good path, or took a long time.
- Examples: no pinned last-known-good version; rollback itself untested; recovery required
  manual multi-step surgery under pressure; no feature flag to disable the bad path quickly.
- Fixes toward: **mitigate** action items (one-command rollback, tested rollback, kill-switch flags).

---

## Other Common Factors

- **Cascading dependency failure** — one component's failure propagated because of no
  circuit breaker, timeout, or bulkhead.
- **Capacity / resource exhaustion** — disk, memory, connection pool, or quota ran out
  with no headroom alert.
- **Config drift** — production diverged from what was tested or declared.
- **Time pressure / change batching** — a large or rushed change bundled many risks at once.
- **Third-party / upstream change** — an external dependency changed behavior with no
  contract test to catch it.

Naming the factors is the analytical core of the postmortem. A postmortem that lists only
one factor has almost certainly stopped too early.
