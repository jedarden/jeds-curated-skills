# Runbook: `--fast` — five-minute go / no-go

For "is this safe to start?" before investing in the full review, or for a plan under ~150
lines. Output is a verdict and the forks, not a memo. No structural sweep.

## Process

1. **Read the plan.** Whole thing — at 150 lines there is no excuse; at 1,500, headers plus
   the Architecture, Data, Phasing, and Open Questions sections in full.
2. **Run the locator:**
   ```bash
   ~/.claude/skills/plan-review/scripts/find-forks.sh <plan>
   ```
   Every DEFER and SHADOW hit is a candidate fork; every UNQUANTIFIED hit is a knob without a
   number. Read the line, decide if it is real.
3. **Walk the seven caps** (SKILL.md Step 6). Each is a yes/no with a line number.
4. **Walk the high-stakes rows of the ledger catalog only** (`references/DECISION-LEDGER.md`,
   rows marked **H**): language, deployment unit, source of truth, storage engine, schema
   evolution, ID scheme, wire format, backup/restore, concurrency, failure policy, auth,
   exposure, secrets path, first slice, rollback. State each in one word.
5. **Thirty-second dry run:** "First file I create in Phase 0 is …; the first thing I must
   decide that the plan didn't is …". One question is enough to know.

## Output

```
Fast review: <plan> @ <sha/date>
Verdict: NOT READY (Cap C4) · READY AFTER DECISIONS (3) · READY

Caps: C1 pass · C2 n/a · C3 pass · C4 TRIPPED · C5 unverified · C6 pass · C7 pass
High-stakes forks:
  language LOCKED · deploy unit LOCKED · source of truth LOCKED · storage ASSERTED ·
  schema evolution UNNOTICED · IDs ASSERTED · wire format LOCKED · backup DEFERRED (:87) ·
  concurrency LOCKED · failure policy UNNOTICED · auth LOCKED · exposure LOCKED ·
  secrets LOCKED · first slice MISSING · rollback UNNOTICED
First implementer question: "<…>" (:line)

Recommendation: run the full review (the three UNNOTICED forks need proposals) ·
                 fix Cap Cn first · safe to decompose
```

## Decision matrix

| Caps tripped | High-stakes open forks | Verdict |
|---|---|---|
| any | — | NOT READY — fix the cap |
| 0 | 0 | READY (full review optional) |
| 0 | 1–3 | READY AFTER DECISIONS — run the full review to get proposals |
| 0 | 4+ | run the full review; the plan is a sketch |

A fast review never says "88%". It says which forks are open.
