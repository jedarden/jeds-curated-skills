---
name: postmortem
version: 1.0.0
description: >-
  Author a blameless incident postmortem from an incident description and any available
  artifacts (logs, timeline notes, chat transcripts), or review an existing draft for
  blameless tone and analytical depth. Builds a timestamped timeline, quantified impact,
  contributing-factor analysis, and owned action items. Use when an incident is resolved
  and needs a written retrospective, or when a draft postmortem needs a quality pass.
argument-hint: "[incident summary or path/to/draft.md]"
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Postmortem Skill

Produce a complete blameless incident postmortem. The goal is organizational learning,
not attribution. Every finding targets systems and process — never people. Impact is
quantified, the timeline includes detection and each mitigation attempt, analysis goes
beyond a single root cause to contributing factors, and every action item has an owner,
a due date, and a prevent/detect/mitigate classification.

This skill operates in two modes:
- **Author mode** (default) — construct a postmortem from an incident description and artifacts.
- **Review mode** — rate an existing draft against the quality checklist and suggest fixes.

## Step 1: Determine Mode and Gather Inputs

If the argument is a path to an existing markdown file that already contains postmortem
sections (summary, timeline, root cause), enter **Review mode** — skip to Step 5.

Otherwise enter **Author mode**. Collect what you can without asking the user:
- The incident summary from the argument or the conversation brief.
- Any artifact paths mentioned (log files, timeline notes, chat transcripts, alert exports).
  Read or `grep` them for timestamps, error signatures, deploy markers, and alert fire/resolve times.
- Scan the working directory for obvious artifacts: `*.log`, `incident*.md`, `timeline*`,
  `*.json` alert exports.

Only ask the user (via AskUserQuestion, 2-3 questions max) if the **core facts are missing**:
what broke, when it started and ended, and the user-facing impact. Do not interrogate for
detail the artifacts can supply.

## Step 2: Load the Template and Checklist

Read both of these from this skill's directory (`~/.claude/skills/postmortem/`):
- `POSTMORTEM-TEMPLATE.md` — the document structure to produce.
- `CHECKLIST-QUALITY.md` — the bar the finished document must clear.

## Step 3: Load the References

Read both reference files so the analysis is blameless and deep:
- `~/.claude/skills/postmortem/references/BLAMELESS-GUIDE.md` — before/after phrasing
  to convert person-blame into systemic statements.
- `~/.claude/skills/postmortem/references/CONTRIBUTING-FACTORS.md` — common factor
  categories to prompt analysis past the first cause.

## Step 4: Spawn the Postmortem Author

Spawn the `subagents/postmortem-author.md` agent. Pass it:
1. The incident summary and all gathered facts.
2. The artifact paths (so it can read them directly for timestamps and signatures).
3. The contents of `POSTMORTEM-TEMPLATE.md`.
4. The contents of both reference files.

The agent builds the timeline, quantifies impact, runs a causal-chain / 5-whys analysis
to surface contributing factors, and drafts concrete owned action items.

## Step 5: Self-Check Against the Quality Checklist

Rate the draft (the author's output, or the user's draft in Review mode) against every
item in `CHECKLIST-QUALITY.md`: **PRESENT / PARTIAL / MISSING**. Pay special attention to:
- Blameless language — no name used as blame, no "human error" as a terminal cause.
- Impact is quantified (users, duration, SLO/error budget, revenue where known).
- Timeline includes detection time and each mitigation attempt, not just start and end.
- Analysis names contributing factors beyond one root cause.
- Every action item has an owner, a due date, and a prevent/detect/mitigate type.
- No action item is merely "be more careful" or "pay more attention."
- A "where we got lucky" section is present.

Fix every PARTIAL and MISSING item before writing the final document.

## Step 6: Write the Postmortem

**Author mode:** Write the finished postmortem to a file (default
`POSTMORTEM-<short-slug>.md` in the working directory, or a path the user specified).
Then report the scorecard and the action-item list.

**Review mode:** Do not overwrite the user's draft. Report the checklist scorecard,
the specific blameless-tone violations with suggested rewrites, the analytical gaps,
and any action items missing an owner/date/type. Offer to apply the fixes.

## Step 7: Emit CandidateLesson Records

**Author mode only:** After the postmortem is written, generate CandidateLesson records
to capture the reusable learning for future incident prevention.

The postmortem-author agent (from Step 4) will have identified lesson-worthy patterns
as part of its analysis. It should now write lesson records to the target repository:

**For each pattern identified:**
1. Generate the lesson ID as `sha256sum(fingerprint + scope) | cut -c1-16`
2. If the lesson file already exists at `docs/notes/lessons/<id>.md`, skip writing
   (this makes the operation idempotent — repeated incidents don't create duplicates)
3. Otherwise, write the lesson file using the template at `templates/lesson.md`
4. Verify all evidence references resolve before writing

**Lesson records go ONLY to:** `docs/notes/lessons/<lesson-id>.md` in the target repository.
No lesson file should ever be written elsewhere.

**Report:** Count of lesson records written, their paths, and the fingerprints captured.

### Extract Key Failure Patterns

From the completed postmortem, identify:

1. **Failure fingerprint:** A concise, unique signature of what went wrong
   - Format: `<failure-type>:<component>:<missing-guardrail>`
   - Example: `deploy-without-test:payment-service:missing-rollback-plan`
   - This identifies the pattern that this incident represents

2. **Scope:** Where this lesson applies
   - `repo-wide` if it's a general process issue
   - `path:<directory>` if it's specific to a subsystem
   - `cluster:<name>` if it's cluster-specific
   - `service:<name>` if it's service-specific

3. **Proposed rule text:** A clear, actionable rule that would prevent recurrence
   - Must be verifiable (can be checked by automation or review)
   - Should be specific, not vague
   - Example: "All production deployments must have a tested rollback plan documented"

4. **Proposed gate or hook change:** Specific automation to enforce the rule
   - Pre-commit hook, CI gate, deployment guardrail
   - Be specific about what change and where
   - Example: "Add pre-deployment check that verifies rollback plan exists in manifest"

5. **Evidence references:** Links to the supporting artifacts
   - Postmortem file path (required)
   - Log files, tickets, alert histories (if available)
   - These must be real, resolvable references

6. **Severity:** Impact tier of this lesson
   - `info`: Process improvement, low urgency
   - `warn`: Important gap, should address
   - `crit`: Serious safety hole, address soon

7. **Expiry:** When this lesson should be revisited
   - Use ISO 8601 date for time-bound lessons: `2027-12-31`
   - Use `never` for permanent lessons

### Generate Stable Lesson ID

The lesson ID is a content hash of `failure_fingerprint + scope`. This ensures:
- The same failure pattern in the same scope updates the same lesson file
- Repeated incidents strengthen the evidence rather than creating duplicates
- The ID is deterministic and stable

Generate the hash using SHA-256 of the concatenated string:
```bash
echo -n "${failure_fingerprint}${scope}" | sha256sum | cut -c1-16
```

### Load the Lesson Template

Read `templates/lesson.md` from this skill's directory as the base structure.

### Write the Lesson Record

Write the lesson file to the target repository's `docs/notes/lessons/` directory:
- Path: `docs/notes/lessons/<lesson-id>.md`
- If the directory doesn't exist, create it: `mkdir -p docs/notes/lessons/`
- If a lesson with this ID already exists, append the new evidence to the
  existing file rather than overwriting it. This builds a stronger case over time.

### Validate Evidence References

Before writing, verify every evidence reference resolves:
- Postmortem path must exist (or be the file just written)
- Log file paths must exist (or warn if they don't)
- Ticket IDs must be valid identifiers (format check only)

### Quality Check

The lesson record is complete only when:
- All YAML frontmatter fields are populated
- The ID is the correct hash of fingerprint+scope
- Every evidence reference resolves to a real file or identifier
- The proposed rule text is verifiable and specific
- The scope is appropriate for the lesson

Report the lesson file path and a summary of what was captured (fingerprint,
scope, severity, expiry).
