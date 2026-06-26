# Runbook: Emergency Hotfix Fast Path

Use when a live incident forces an urgent fix and the full gate set would cost more than the
outage. This is a reduced gate set, not a no-gate set. The goal: ship the fix fast without
creating a second incident.

---

## When to Use

- A production defect is actively causing harm (data loss, outage, security exposure).
- Waiting for the full readiness review would extend the incident.
- The change is narrowly scoped to the fix — not bundled with unrelated work.

If the change is not strictly the fix, it is NOT a hotfix. Split it.

---

## Gates You MAY Skip (when time-critical)

These are deferred to a follow-up cleanup release, not abandoned:

- **2.2 Changelog Updated** — a one-line entry now, full notes in the follow-up.
- **4.1 Docs / README Updated** — defer to follow-up.
- **4.4 API Reference Regenerated** — defer to follow-up (only if the public API is unchanged).
- **1.5 Coverage Not Regressed** — accept a regression test added in the follow-up if the fix itself is verified.
- **3.6 Runbook Updated** — defer, but capture the incident notes somewhere durable.

---

## Gates You MUST NEVER Skip

No matter how urgent, these are non-negotiable — skipping them is how a hotfix becomes a
bigger outage:

- **1.1 Tests Pass** — at minimum, the fix is verified and nothing obviously broke. A test
  that reproduces the bug and now passes is the strongest evidence.
- **1.3 Build Succeeds** — never deploy an artifact that did not build cleanly.
- **3.1 Rollback Plan Exists** — you MUST be able to get back to the last-known-good state
  instantly. This is the single most important hotfix gate.
- **3.2 Migrations Reversible** — a hotfix that ships an irreversible destructive migration
  is forbidden. Defer the migration; ship code-only if at all possible.
- **3.5 Config & Secrets in Place** — the fix cannot depend on config that does not yet exist
  in production.
- **Change tracking** — the hotfix is committed, tagged, and attributed. Never hand-patch a
  live box without a corresponding commit. An untracked live edit is itself an incident.

---

## Process

1. Run `scripts/scan-release.sh` to capture exactly what is changing.
2. Confirm the diff is ONLY the fix.
3. Verify the MUST-NEVER-SKIP gates with evidence (run the fix's test, confirm the build,
   write down the rollback command).
4. Spawn the `release-auditor` subagent with the reduced gate set and the note that this is a
   hotfix; require an explicit GO on every must-never-skip gate.
5. Ship. Tag the release.
6. Open a follow-up to clear every deferred gate. The hotfix is not "done" until the
   follow-up lands.

---

## Verdict Rule for Hotfixes

- **NO-GO** if ANY must-never-skip gate is not PRESENT.
- **CONDITIONAL** is the best a hotfix gets while deferred gates are open — record the
  follow-up.
- A clean **GO** requires all must-never-skip gates PRESENT and a follow-up filed for the rest.
