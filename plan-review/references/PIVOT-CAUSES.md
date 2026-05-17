# Common In-Flight Pivot Causes

Catalog of reasons plans stall or require mid-implementation pivots,
derived from analysis of 88 planning documents and their stated failure modes.

Use this when diagnosing a plan's specific risks or when explaining to the user
why a missing checklist item matters.

---

## Category 1 — Scope Failures

### SC-1: "We Had Different Mental Models"
**Cause:** No glossary. Key terms meant different things to different implementers.
**Signal in plan:** Technical terms used without definition; team has multiple backgrounds.
**Pivot type:** Architecture redesign after discovering disagreement.

### SC-2: "Scope Crept In During Phase 3"
**Cause:** Non-goals not stated with rationale. Seemed reasonable to add at the time.
**Signal in plan:** Non-goals section missing or just a list without "why."
**Pivot type:** Timeline extension; features partially built; priority conflicts.

### SC-3: "We Accidentally Rebuilt What Y Already Does"
**Cause:** Adjacent system boundaries not defined. Responsibility overlap assumed away.
**Signal in plan:** No section on what neighboring tools own.
**Pivot type:** Wasted work; integration conflict discovered late.

### SC-4: "The Plan Was 6 Months Stale"
**Cause:** No date stamp or revision history. Implementers followed outdated decisions.
**Signal in plan:** No metadata on document freshness.
**Pivot type:** Re-implementing decisions that had already been reversed.

---

## Category 2 — "Done" Definition Failures

### DD-1: "We Built It But It Wasn't What They Wanted"
**Cause:** No named acceptance scenarios. Features built, but success undefined.
**Signal in plan:** Feature list instead of "user does X, system does Y, user sees Z."
**Pivot type:** Post-build redesign; UX overhaul.

### DD-2: "Works on My Machine"
**Cause:** No pass/fail criteria. "It works" accepted without definition.
**Signal in plan:** Acceptance scenarios present but criteria are vague.
**Pivot type:** Re-testing; late QA; customer escalation.

### DD-3: "It Works for Humans But Not for Scripts"
**Cause:** No agent/automation scenario specified.
**Signal in plan:** Only human use cases described; no machine-mode scenario.
**Pivot type:** Breaking API changes post-ship; automation glue code.

---

## Category 3 — Architecture Failures

### AR-1: "We Argued About the Storage Backend for 3 Weeks"
**Cause:** Technology decisions not locked as ADRs upfront. Churn-magnets left open.
**Signal in plan:** "We'll decide on storage later" or similar deferred decisions.
**Pivot type:** Extended design debates; delayed implementation start.

### AR-2: "The Concurrency Model Doesn't Fit"
**Cause:** Concurrency model unspecified or assumed to be "we'll figure it out."
**Signal in plan:** No threading/ownership model section.
**Pivot type:** Fundamental redesign; data race bugs; rewrite of hot paths.

### AR-3: "That Dependency Isn't Available in This Environment"
**Cause:** No dependency integration contracts specifying behavior when unavailable.
**Signal in plan:** Dependencies listed but not contracted.
**Pivot type:** Runtime failures in CI/prod; emergency fallback implementation.

### AR-4: "We Don't Know Where This Code Should Live"
**Cause:** No file/module layout defined upfront.
**Signal in plan:** Architecture described but no directory structure.
**Pivot type:** Inconsistent organization; refactoring churn.

---

## Category 4 — Pre-Flight Safety Failures

### PF-1: "We Didn't Think About That Edge Case"
**Cause:** No edge case catalog. Edge cases discovered during testing or in production.
**Signal in plan:** Edge cases mentioned inline, not in a dedicated catalog.
**Pivot type:** Emergency patches; production incidents.

### PF-2: "We Have No Way to Roll Back"
**Cause:** Rollback plan not specified at design time.
**Signal in plan:** Destructive operations described without rollback artifacts.
**Pivot type:** Production incidents with no recovery path; data loss.

### PF-3: "It Breaks When the Network Is Down"
**Cause:** No offline/degraded mode specification.
**Signal in plan:** All features assume connectivity.
**Pivot type:** User-facing failures; emergency offline fallback.

### PF-4: "We Keep Making the Same Mistake"
**Cause:** No anti-patterns catalog. Implementers reinvent bad solutions.
**Signal in plan:** Known bad approaches not documented.
**Pivot type:** Repeated rework; code review cycles.

---

## Category 5 — Implementation Phasing Failures

### PH-1: "We Don't Know If We're On Track"
**Cause:** Phases without completion criteria. "Done" is fuzzy.
**Signal in plan:** Phases described as task lists, not testable exit conditions.
**Pivot type:** Schedule slippage invisible until too late.

### PH-2: "Phase 2 Built on Broken Phase 1"
**Cause:** No phase entry criteria. Phase 2 started before Phase 1 was solid.
**Signal in plan:** No "must pass before proceeding" gates between phases.
**Pivot type:** Cascading bugs; foundation rework mid-build.

### PH-3: "We Underestimated the Scope by 5x"
**Cause:** No LOC/scope estimate. Ambition not calibrated to reality.
**Signal in plan:** No size estimate; plan reads as ambitious but unconstrained.
**Pivot type:** Feature cuts under pressure; rushed final phases.

---

## Category 6 — Testing Failures

### TE-1: "The Tests Pass But the Port Is Wrong"
**Cause:** No conformance harness. Testing internal correctness, not output correctness.
**Signal in plan:** Tests described but no comparison against original system.
**Pivot type:** Behavioral divergence discovered after shipping.

### TE-2: "Benchmarks Were Advisory and Nobody Watched Them"
**Cause:** Benchmarks not CI-gated. Regressions accumulated silently.
**Signal in plan:** Performance section exists but not gated.
**Pivot type:** Performance "crisis" requiring dedicated optimization sprint.

### TE-3: "We Found the Bug in Production"
**Cause:** Failure modes not paired with tests at design time.
**Signal in plan:** Failure modes described but no "test for each" requirement.
**Pivot type:** Emergency patches; production incidents.

---

## Category 7 — Operational Failures

### OP-1: "Nobody Documented How to Install It"
**Cause:** No deployment/installation plan. Assumed "obvious."
**Signal in plan:** Implementation detailed but deployment path absent.
**Pivot type:** Adoption blockers; support burden.

### OP-2: "The Migration Broke Existing Users"
**Cause:** No keep/drop/reinterpret matrix. Backward compat stance implicit.
**Signal in plan:** Replaces existing system but no migration plan.
**Pivot type:** Rollback; emergency compatibility shim.

### OP-3: "You Can't Run This in CI"
**Cause:** No non-interactive mode. All prompts require human input.
**Signal in plan:** CLI tool with interactive prompts, no `--yes` / `--no-interactive` flag.
**Pivot type:** Automation blocked; CI integration work.

### OP-4: "There's No Way to Know If It's Healthy"
**Cause:** No `doctor` command / health check. No monitoring spec.
**Signal in plan:** Tool described without a self-diagnostic capability.
**Pivot type:** Support escalations; "is it running?" incidents.

---

## Category 8 — Performance Failures

### PE-1: "It's Not Fast Enough and We Have to Rewrite the Hot Path"
**Cause:** Performance budgets not stated before implementation.
**Signal in plan:** No numeric SLOs; "fast" without definition.
**Pivot type:** Post-ship optimization sprint; sometimes partial rewrite.

### PE-2: "The Benchmark Doesn't Prove What We Claimed"
**Cause:** No benchmark denominator contract. Measurement methodology ambiguous.
**Signal in plan:** "3x faster" claimed without specifying compared to what, measured how.
**Pivot type:** Credibility loss; re-benchmarking sprint.

---

## Category 9 — Security Failures

### SE-1: "A Secret Got Logged"
**Cause:** No explicit "never log secrets" policy stated as design constraint.
**Signal in plan:** Secrets handling section absent or vague.
**Pivot type:** Security incident; audit finding; emergency patch.

### SE-2: "We Didn't Think About That Attack Vector"
**Cause:** No threat model. Security left to "we'll add it later."
**Signal in plan:** No threat model section.
**Pivot type:** Security review failure; post-ship hardening.
