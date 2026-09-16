# Self-Test: plan-gap-review

Prose-only skill — the surface is the loop: analyze (fresh-eyes agent) → fix
in batches of 5 (20-solutions-per-gap) → commit per round → re-analyze until
0 gaps / LOW-only / 5 rounds. There is no checklist file; the regression shape
is a fixture plan with seven planted, enumerable gaps and a clean fixture for
the loop's exit condition.

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

**Expected findings inventory — round 1 against this fixture:**

| # | Planted gap | Category | Severity | Hard pin? |
|---|-------------|----------|----------|-----------|
| 1 | §2 "SQLite, single node, one file" vs §7 "clustered ingestion service" | CONSISTENCY | HIGH–CRITICAL | **Category + findability are hard pins** |
| 2 | `docs/plan/storage-cluster.md` referenced, does not exist | STRUCTURAL | MEDIUM | Hard pin (mechanically checkable) |
| 3 | `docs/adr/0009-ingestion.md` referenced, does not exist | STRUCTURAL | MEDIUM | Hard pin (mechanically checkable) |
| 4 | §1 "CLI" vs §6 "embedded web dashboard" never introduced | UX | MEDIUM | Hard pin |
| 5 | User-supplied CSV paths with no validation/sandboxing note | SECURITY | CRITICAL | **Category + severity are hard pins** |
| 6 | Section numbering jumps 4 → 6 (no §5) | STRUCTURAL | LOW | Hard pin |
| 7 | Superseded export decision left in place | CONSISTENCY | LOW | Expected, may merge with #1 |

The round-1 report must name **at least 5 of the 7**, every finding must use
one of the five fixed categories (STRUCTURAL/TECHNICAL/SECURITY/UX/
CONSISTENCY) and one of the four severities, and each finding carries a
location and a suggested fix. Finding #5 at anything below CRITICAL, or #1
missed entirely, means the analysis prompt lost the plot. Cosmetic-only
findings (wording, formatting) when planted defects sit unfixed = the "no
cosmetic nitpicks" principle failing.

**Loop shape:** fixes are applied by Edit (surgical, not rewrite), the round's
fixes are **committed separately** with a message listing the gaps fixed, and
round 2 re-analyzes with a *fresh* agent. The loop exits when a round finds 0
gaps, only LOWs (asks the user), or 5 rounds. On this fixture expect 2–3
rounds to zero.

## Fixture B — clean document (loop exit condition)

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

**Expected:** round 1 finds **0 gaps** — the loop exits immediately with a
report of zero, **no commits made** (`git log` on the scratch repo shows only
the init commit), no manufactured findings. A "found" nitpick here is the
regression.

## Expected Behaviors

- **Batches of 5**: with >5 gaps, fix agents run in parallel batches, tracked
  via TaskCreate and marked completed — not one mega-edit.
- **20 solutions per gap, ranked by fit with the document's goal**: the fix
  chosen for a planted gap should read like it belongs to the document, and
  the fix agent reports what it changed.
- **Surgical edits**: planted text is repaired in place; the document's other
  content survives byte-for-byte where untouched.
- **Fresh eyes each round**: no analysis agent carries memory of the previous
  round's findings — round 2 must re-derive, not resume.
- **Final report**: total gaps found/fixed, breakdown by category and
  severity, remaining open items, final line count.
