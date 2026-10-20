# Self-Test: plan-gap-review

Prose-only skill — the surface is bounded delegated analysis (a fresh child
for substantial documents) → authorized fixes applied directly, with any
finding that expands scope or needs a new decision batched for one explicit
review → verify → report. There is no checklist file; the regression shape
is a fixture plan with seven planted, enumerable gaps and a clean fixture for
the "don't manufacture findings" guard.

(2026-10-10: rewritten for the skill's bounded-delegation/admission-batch
redesign — the earlier revision of both SKILL.md and this file described a
fixed "20-solutions-per-gap, batches of 5, loop until 0 gaps or 5 rounds"
shape that no longer exists. The planted-gap fixture content is unchanged;
only the workflow expectations around it are corrected below.)

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "find gaps in this plan" | Activates |
| "review this spec for contradictions" | Activates |
| "polish this document" | Activates |
| "/plan-gap-review docs/plan/plan.md" | Activates |
| "compare the plan to what got built" | Does NOT activate — plan-vs-built territory, not gap review |

## Structure

Single file — `SKILL.md`, no checklists/scripts/subagents:

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
ls -1 "$REPO/plan-gap-review"   # SKILL.md and SELF-TEST.md only
grep -q 'bounded delegated analysis' "$REPO/plan-gap-review/SKILL.md" && echo "ok: current design"
```

## Fixture A — planted gaps (in a throwaway git repo; the skill commits)

Seven defects, each from a different corner of the skill's scan list:

```bash
T="$(mktemp -d)" && git -C "$T" init -q
cat > "$T/plan.md" <<'EOF'
# Gadgetline — plan

## 1. Overview

Gadgetline is a CLI that indexes gadget inventory from CSV exports into a
searchable local store.

## 2. Storage

Storage is SQLite, single node, WAL mode. The whole index lives in one file
beside the binary.

## 3. Ingestion

The importer reads CSVs given on the command line. Paths come straight from
the user. (planted: no path validation / sandboxing story)

## 4. Query

Queries filter by name, serial, and location.

## 6. API

The HTTP API is served on port 8080 by the embedded web dashboard.
(planted: UX inconsistency — section 1 says CLI-only, no dashboard was
introduced anywhere; also planted: numbering jumps 4 → 6)

## 7. Future

The importer will move to the clustered ingestion service described in
docs/plan/storage-cluster.md. (planted: dangling reference — file does not
exist) See also the ADR in docs/adr/0009-ingestion.md. (planted: dangling
reference — file does not exist)

Note: the old section 8 decision about exports was superseded by section 2 of
this document. (planted: dead/superseded content left in place)
EOF
echo "$T" > /tmp/pgr-selftest-dir
```

**Expected findings inventory — the analysis pass against this fixture:**

| # | Planted gap | Category | Severity | Hard pin? |
|---|-------------|----------|----------|-----------|
| 1 | §2 "SQLite, single node, one file" vs §7 "clustered ingestion service" | CONSISTENCY | HIGH–CRITICAL | **Category + findability are hard pins** |
| 2 | `docs/plan/storage-cluster.md` referenced, does not exist | STRUCTURAL | MEDIUM | Hard pin (mechanically checkable) |
| 3 | `docs/adr/0009-ingestion.md` referenced, does not exist | STRUCTURAL | MEDIUM | Hard pin (mechanically checkable) |
| 4 | §1 "CLI" vs §6 "embedded web dashboard" never introduced | UX | MEDIUM | Hard pin |
| 5 | User-supplied CSV paths with no validation/sandboxing note | SECURITY | CRITICAL | **Category + severity are hard pins** |
| 6 | Section numbering jumps 4 → 6 (no §5) | STRUCTURAL | LOW | Hard pin |
| 7 | Superseded export decision left in place | CONSISTENCY | LOW | Expected, may merge with #1 |

The analysis must name **at least 5 of the 7**, every finding must use one of
the five fixed categories (STRUCTURAL/TECHNICAL/SECURITY/UX/CONSISTENCY) and
one of the four severities, and each finding carries a location and a
suggested fix. Finding #5 at anything below CRITICAL, or #1 missed entirely,
means the analysis prompt lost the plot. Cosmetic-only findings (wording,
formatting) when planted defects sit unfixed = the "no cosmetic nitpicks"
principle failing.

**Fix-and-verify shape:** all seven planted gaps are ordinary corrections
within the original authorization (none require a new product decision), so
every one is fixed directly by Edit — surgical, not a rewrite — with
verification against the actual corrections and affected references. The
commit stages only the exact edited path(s), never a blanket add. A **second
analysis pass is not required** here: inputs haven't changed since the first
pass's findings were resolved, and the skill does not demand a second
identical clean round just to accumulate rounds. Re-analysis is for changed
inputs, a specific unresolved concern, or a required independent check —
none of which apply to this fixture once the fixes land.

**Decision-batching case (describe, don't fixture):** if a planted gap instead
read as a product-decision fork — e.g. "§2 doesn't say whether the single
SQLite file is backed up" where the real question is *should it be* rather
than *document the current behavior* — the skill batches that with any other
real decisions for one explicit admit/reject/defer review rather than
resolving it unilaterally or blocking the rest of the fixes on it. None of
the seven planted gaps above are decision-shaped, so this fixture doesn't
exercise it; verify it manually if touching Step 3's batching logic.

## Fixture B — clean document (no manufactured findings)

```bash
T="$(cat /tmp/pgr-selftest-dir)"
cat > "$T/clean.md" <<'EOF'
# Widgetline — plan

## 1. Overview
Widgetline is a CLI that converts widget manifests to JSON. Single binary,
standard library only.

## 2. Interface
`widgetline in.manifest -o out.json`. Exit 0 on success, 1 on parse error,
2 on I/O error.

## 3. Errors
Parse errors print file, line, and column to stderr. No other output.
EOF
```

**Expected:** the analysis finds **0 gaps** and the skill reports that
directly — no edits, no commits (`git log` on the scratch repo shows only the
init commit), no manufactured findings to justify having run. A "found"
nitpick here is the regression.

## Expected Behaviors

- **Bounded context**: a delegated analysis child gets the objective,
  constraints, and document paths — not the parent's full transcript; its
  useful context can be reused for a focused follow-up rather than
  re-spawned cold every time.
- **Authorization-scoped fixes**: ordinary wording, references, and
  implementation-detail corrections are applied without re-asking; a finding
  that is a new product decision or expands the acceptance boundary is
  batched for one explicit admit/reject/defer review, never self-admitted.
- **One writer per document**: fix agents never concurrently rewrite the same
  file; independent analysis or edits to disjoint documents may parallelize.
- **Surgical edits**: targeted corrections, not rewrites — existing content
  not implicated by a finding survives untouched.
- **Outcome ownership**: implementation, verification, and delivery for a
  finding stay on its owning bead — no separate bead or task is created
  merely to repeat analysis or re-record evidence already proven.
- **No redundant re-analysis**: repeat only for changed inputs, a specific
  unresolved concern, or a required independent check; a cosmetic edit does
  not restart a full review, and a single clean pass is sufficient evidence
  when nothing changed since it ran.
- **No cosmetic nitpicks**: findings are gaps that would cause implementation
  confusion, a security issue, or a user-facing bug — not wording preference.
- **Round budget**: each round reports findings closed, findings its own edits
  introduced, and net line growth; a round that opens more than it closes ends
  the invocation with a report, and two rounds is the ceiling without new
  outside input. On Fixture A one round closes all seven with zero introduced,
  so a second round never starts.
- **Exact-path staging**: commits name the precise edited paths, never a
  blanket `git add -A` / `git commit -a`, so a shared checkout's other
  in-flight edits are never swept in.
