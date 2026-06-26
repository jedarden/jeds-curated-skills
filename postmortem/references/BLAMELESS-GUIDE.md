# Blameless Phrasing Guide

A postmortem is blameless when it can be read aloud with the responsible engineer in the
room and contain no sentence they would dread. The discipline: every time a person appears
in the analysis, redirect to the system that allowed the outcome. People act rationally
given the information and tools they have. If the result was bad, the system — not the
person — is the thing to fix.

## The Core Move

When you write a sentence with a person as the subject of a mistake, rewrite it with the
**system or process** as the subject and the person's action as a normal, expected event
that the system failed to catch or constrain.

## Before → After Examples

**Blame:** "Dana deployed the change without running the migration first."
**Blameless:** "The deploy pipeline allowed the application to ship ahead of its database
migration. There was no gate enforcing migration-before-deploy ordering."

---

**Blame:** "The on-call engineer didn't notice the error rate climbing for 20 minutes."
**Blameless:** "No alert fired on the error-rate climb; detection depended on an engineer
happening to watch the dashboard. Time-to-detect was 20 minutes because detection was manual."

---

**Blame:** "Someone fat-fingered the config and set the timeout to 5ms instead of 5s."
**Blameless:** "A config value was set to 5ms. The config had no validation or sane-range
check, and no staging gate caught the value before it reached production."

---

**Blame:** "The new hire didn't know you have to drain the node before restarting it."
**Blameless:** "The node-restart procedure required a manual drain step that was not
enforced by tooling and was not in the runbook. The drain was easy to skip."

---

**Blame:** "QA missed the bug."
**Blameless:** "The test suite had no coverage for the empty-payload case that triggered
the failure. The case was reachable in production but untested."

---

**Blame:** "He rolled back to the wrong version and made it worse."
**Blameless:** "The rollback procedure did not pin a known-good version, so the operator
had to choose one under pressure. The version list gave no health signal to guide the choice."

## "Human Error" Is a Starting Point, Not an Answer

"Human error" is never where the analysis ends. It is the prompt for the next question:
*why did the system make this error easy to make and hard to catch?* Every "someone forgot"
maps to a missing guardrail. Every "they didn't know" maps to a knowledge silo or a missing
runbook. Push through to the systemic factor — that is the thing an action item can fix.

## Words to Avoid

- Names attached to mistakes ("X broke", "Y forgot", "Z should have").
- "Negligence", "careless", "sloppy", "obviously should have known".
- "Just" and "simply" ("they should have just checked") — these smuggle in blame by
  implying the right action was trivial. It rarely was, given what they could see.
- "Root cause: human error" as a terminal statement.

## Words to Prefer

- "The system allowed…", "There was no guardrail preventing…", "Detection depended on…",
  "The procedure required a manual step that…", "Coverage was missing for…".
- Subject of the sentence is a system, a process, a gap, or a tool — not a person.
